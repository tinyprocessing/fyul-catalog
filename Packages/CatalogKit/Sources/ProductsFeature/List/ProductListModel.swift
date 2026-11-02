import CatalogCore
import Foundation
import Observation
import os

/// Owns the list: query, pagination, refresh and connectivity.
///
/// Every first-page load bumps `generation`. Responses from an older generation are dropped,
/// so a slow page of the previous query can never land in the current one.
@MainActor
@Observable
public final class ProductListModel {
    public enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case failed(APIError)
    }

    public enum PageState: Equatable {
        case idle
        case loading
        case failed(APIError)
        case exhausted
    }

    public private(set) var products: [ProductSummary] = []
    public private(set) var phase: Phase = .loading
    public private(set) var pageState: PageState = .idle
    public private(set) var categories: [ProductCategory] = []
    public private(set) var query: ProductQuery = .all
    public private(set) var isOffline = false
    /// A refresh failed while older content is still on screen.
    public private(set) var refreshError: APIError?

    public var searchText = "" {
        didSet { searchTextChanged() }
    }

    public var isSearching: Bool { !query.search.isEmpty }

    @ObservationIgnored private let dependencies: CatalogDependencies
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var nextSkip = 0
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var firstPageTask: Task<Void, Never>?
    @ObservationIgnored private var nextPageTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    public init(dependencies: CatalogDependencies) {
        self.dependencies = dependencies
    }

    /// Call from `.task`. Loads once, then follows connectivity until the view goes away.
    public func start() async {
        if !hasStarted {
            hasStarted = true
            loadFirstPage()
            Task { await loadCategories() }
        }
        for await online in dependencies.connectivity.isOnline() {
            let reconnected = isOffline && online
            isOffline = !online
            if reconnected { recoverAfterReconnect() }
        }
    }

    // MARK: Query

    public func selectCategory(_ slug: String?) {
        var query = query
        query.categorySlug = slug
        query.search = ""
        apply(query)
        searchText = ""
    }

    public func selectSort(_ sort: SortOption) {
        var query = query
        query.sort = sort
        apply(query)
    }

    /// Remote config can withdraw a sort option while it is selected.
    public func apply(_ flags: FeatureFlags) {
        if !flags.sortOptions.contains(query.sort) {
            selectSort(.featured)
        }
    }

    private func searchTextChanged() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let effective = trimmed.count >= dependencies.search.minimumQueryLength ? trimmed : ""
        searchTask?.cancel()
        guard effective != query.search else { return }
        searchTask = Task { [weak self, dependencies] in
            do {
                try await dependencies.sleep(dependencies.search.debounce)
            } catch {
                return
            }
            guard let self else { return }
            var query = self.query
            query.search = effective
            self.apply(query)
        }
    }

    private func apply(_ newQuery: ProductQuery) {
        guard newQuery != query else { return }
        Log.products.info("Query changed: \(String(describing: newQuery), privacy: .private)")
        query = newQuery
        // Results of the previous query must not stay visible under the new one.
        products = []
        refreshError = nil
        phase = .loading
        loadFirstPage()
    }

    // MARK: Loading

    public func retry() {
        refreshError = nil
        if products.isEmpty { phase = .loading }
        loadFirstPage()
    }

    /// Pull to refresh: keeps current content on screen until the new page arrives.
    public func refresh() async {
        loadFirstPage()
        await firstPageTask?.value
    }

    public func loadMoreIfNeeded(after product: ProductSummary) {
        guard phase == .loaded, pageState == .idle else { return }
        let threshold = products.count - dependencies.paging.prefetchDistance
        guard let index = products.lastIndex(where: { $0.id == product.id }), index >= threshold else { return }
        loadNextPage()
    }

    public func retryNextPage() {
        guard case .failed = pageState else { return }
        loadNextPage()
    }

    private func loadFirstPage() {
        generation += 1
        let generation = generation
        let query = query
        let limit = dependencies.paging.pageSize
        firstPageTask?.cancel()
        nextPageTask?.cancel()
        if pageState == .loading { pageState = .idle }
        firstPageTask = Task { [weak self, products = dependencies.products] in
            do {
                let page = try await products.products(for: query, skip: 0, limit: limit)
                self?.finishFirstPage(page, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                self?.failFirstPage(error.asAPIError, generation: generation)
            }
        }
    }

    private func finishFirstPage(_ page: Page<ProductSummary>, generation: Int) {
        guard generation == self.generation else {
            Log.products.debug("Dropped stale first page from generation \(generation, privacy: .public)")
            return
        }
        Log.products.info("First page: \(page.items.count, privacy: .public) of \(page.total, privacy: .public)")
        products = page.items.uniquedByID()
        nextSkip = page.skip + page.items.count
        refreshError = nil
        phase = products.isEmpty ? .empty : .loaded
        pageState = page.hasMore && !page.items.isEmpty ? .idle : .exhausted
    }

    private func failFirstPage(_ error: APIError, generation: Int) {
        guard generation == self.generation else { return }
        Log.products.error("First page failed: \(String(describing: error), privacy: .public)")
        if products.isEmpty {
            phase = .failed(error)
        } else {
            refreshError = error
        }
    }

    private func loadNextPage() {
        pageState = .loading
        let generation = generation
        let query = query
        let skip = nextSkip
        let limit = dependencies.paging.pageSize
        nextPageTask = Task { [weak self, products = dependencies.products] in
            do {
                let page = try await products.products(for: query, skip: skip, limit: limit)
                self?.finishNextPage(page, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                self?.failNextPage(error.asAPIError, generation: generation)
            }
        }
    }

    private func finishNextPage(_ page: Page<ProductSummary>, generation: Int) {
        guard generation == self.generation else {
            Log.products.debug("Dropped stale page from generation \(generation, privacy: .public)")
            return
        }
        Log.products.info("Page at \(page.skip, privacy: .public): \(page.items.count, privacy: .public) items")
        // Offset paging over a changing catalog can repeat items between pages.
        let known = Set(products.map(\.id))
        products += page.items.uniquedByID().filter { !known.contains($0.id) }
        nextSkip = page.skip + page.items.count
        pageState = page.hasMore && !page.items.isEmpty ? .idle : .exhausted
    }

    private func failNextPage(_ error: APIError, generation: Int) {
        guard generation == self.generation else { return }
        Log.products.error("Page failed: \(String(describing: error), privacy: .public)")
        pageState = .failed(error)
    }

    private func loadCategories() async {
        guard categories.isEmpty else { return }
        categories = (try? await dependencies.products.categories()) ?? []
    }

    private func recoverAfterReconnect() {
        Log.products.info("Back online, recovering failed loads")
        if case .failed = phase {
            retry()
        } else if refreshError != nil {
            loadFirstPage()
        } else if case .failed = pageState {
            retryNextPage()
        }
        if categories.isEmpty {
            Task { await loadCategories() }
        }
    }
}

extension Array where Element == ProductSummary {
    func uniquedByID() -> [ProductSummary] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}

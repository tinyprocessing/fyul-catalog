import CatalogCore
import Foundation
import ProductsFeature
import Testing

@MainActor
@Suite("Product list")
struct ProductListModelTests {
    private let service = ControlledProductService()
    private let connectivity = ManualConnectivity()

    private func makeModel(debounce: Duration = .zero) -> ProductListModel {
        let dependencies = CatalogDependencies(
            products: service,
            connectivity: connectivity,
            paging: .init(pageSize: 10, prefetchDistance: 2),
            search: .init(debounce: debounce, minimumQueryLength: 2),
            currencyCode: "USD"
        )
        return ProductListModel(dependencies: dependencies)
    }

    private func started(_ model: ProductListModel) -> Task<Void, Never> {
        Task { await model.start() }
    }

    private func callCount() async -> Int { await service.calls.count }

    private func tearDown(_ task: Task<Void, Never>) async {
        connectivity.finish()
        await service.finishAll()
        task.cancel()
    }

    @Test("First page shows products")
    func firstLoad() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        #expect(model.phase == .loading)

        await service.respond(to: 0, with: .of(1...10, total: 30))

        await waitUntil { model.phase == .loaded }
        #expect(model.products.map(\.id) == Array(1...10))
        #expect(model.pageState == .idle)
        await tearDown(task)
    }

    @Test("An empty catalog is a state, not an error")
    func emptyCatalog() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }

        await service.respond(to: 0, with: .empty)

        await waitUntil { model.phase == .empty }
        #expect(model.pageState == .exhausted)
        await tearDown(task)
    }

    @Test("A failed first load can be retried")
    func failureThenRetry() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }

        await service.fail(0, with: .server(status: 500, retryAfter: nil))
        await waitUntil { model.phase == .failed(.server(status: 500, retryAfter: nil)) }

        model.retry()
        #expect(model.phase == .loading)
        await waitUntil { await callCount() == 2 }
        await service.respond(to: 1, with: .of(1...5, total: 5))

        await waitUntil { model.phase == .loaded }
        await tearDown(task)
    }

    @Test("Pagination appends, skips duplicates and stops at the total")
    func pagination() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        await service.respond(to: 0, with: .of(1...10, total: 15))
        await waitUntil { model.phase == .loaded }

        // Rows far from the end do not trigger a page.
        model.loadMoreIfNeeded(after: .fixture(3))
        #expect(model.pageState == .idle)

        model.loadMoreIfNeeded(after: .fixture(9))
        #expect(model.pageState == .loading)
        // A second appearance while loading must not start another request.
        model.loadMoreIfNeeded(after: .fixture(10))
        await waitUntil { await callCount() == 2 }
        #expect(await service.calls[1].skip == 10)

        // Item 10 arrives again because the catalog shifted between requests.
        await service.respond(to: 1, with: .of(10...15, total: 15, skip: 10))

        await waitUntil { model.pageState == .exhausted }
        #expect(model.products.map(\.id) == Array(1...15))
        #expect(await callCount() == 2)
        await tearDown(task)
    }

    @Test("A failed page keeps loaded products and can be retried")
    func pageFailure() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        await service.respond(to: 0, with: .of(1...10, total: 20))
        await waitUntil { model.phase == .loaded }

        model.loadMoreIfNeeded(after: .fixture(10))
        await waitUntil { await callCount() == 2 }
        await service.fail(1, with: .timedOut)

        await waitUntil { model.pageState == .failed(.timedOut) }
        #expect(model.products.count == 10)
        #expect(model.phase == .loaded)

        model.retryNextPage()
        await waitUntil { await callCount() == 3 }
        await service.respond(to: 2, with: .of(11...20, total: 20, skip: 10))
        await waitUntil { model.products.count == 20 }
        await tearDown(task)
    }

    @Test("A slow response for an old query never replaces the current one")
    func staleResponseIsDropped() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }

        model.selectSort(.priceHighToLow)
        await waitUntil { await callCount() == 2 }

        await service.respond(to: 1, with: .of(20...25, total: 6))
        await waitUntil { model.phase == .loaded }
        await service.respond(to: 0, with: .of(1...10, total: 10))
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.products.map(\.id) == Array(20...25))
        #expect(model.query.sort == .priceHighToLow)
        await tearDown(task)
    }

    @Test("Changing the query clears old results at once")
    func queryChangeClearsResults() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        await service.respond(to: 0, with: .of(1...10, total: 10))
        await waitUntil { model.phase == .loaded }

        model.selectCategory("laptops")

        #expect(model.products.isEmpty)
        #expect(model.phase == .loading)
        await waitUntil { await callCount() == 2 }
        #expect(await service.calls[1].query.categorySlug == "laptops")
        await tearDown(task)
    }

    @Test("A failed refresh keeps the content and shows a banner")
    func refreshFailureKeepsContent() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        await service.respond(to: 0, with: .of(1...10, total: 10))
        await waitUntil { model.phase == .loaded }

        let refresh = Task { await model.refresh() }
        await waitUntil { await callCount() == 2 }
        await service.fail(1, with: .offline)
        await refresh.value

        #expect(model.products.count == 10)
        #expect(model.phase == .loaded)
        #expect(model.refreshError == .offline)
        await tearDown(task)
    }

    @Test("Typing is debounced: only the final text is searched")
    func searchDebounce() async {
        let model = makeModel(debounce: .milliseconds(100))
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        await service.respond(to: 0, with: .of(1...10, total: 10))
        await waitUntil { model.phase == .loaded }

        model.searchText = "p"
        model.searchText = "ph"
        model.searchText = "pho"
        model.searchText = "phone"

        await waitUntil { await callCount() == 2 }
        try? await Task.sleep(for: .milliseconds(200))
        #expect(await callCount() == 2)
        #expect(await service.calls[1].query.search == "phone")
        await tearDown(task)
    }

    @Test("Text shorter than the minimum and surrounding spaces do not trigger a search")
    func shortOrPaddedQueries() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        await service.respond(to: 0, with: .of(1...10, total: 10))
        await waitUntil { model.phase == .loaded }

        model.searchText = " a "
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await callCount() == 1)

        model.searchText = "  phone  "
        await waitUntil { await callCount() == 2 }
        #expect(await service.calls[1].query.search == "phone")
        await tearDown(task)
    }

    @Test("Coming back online reloads a failed list by itself")
    func reconnectRecovers() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        connectivity.send(false)
        await waitUntil { model.isOffline }
        await service.fail(0, with: .offline)
        await waitUntil { model.phase == .failed(.offline) }

        connectivity.send(true)

        await waitUntil { await callCount() == 2 }
        #expect(!model.isOffline)
        await service.respond(to: 1, with: .of(1...3, total: 3))
        await waitUntil { model.phase == .loaded }
        await tearDown(task)
    }

    @Test("Remote config withdrawing the active sort falls back to featured")
    func withdrawnSortFallsBack() async {
        let model = makeModel()
        let task = started(model)
        await waitUntil { await callCount() == 1 }
        model.selectSort(.lowStockFirst)
        await waitUntil { await callCount() == 2 }

        var flags = FeatureFlags.defaults
        flags.sortOptions = [.featured, .topRated]
        model.apply(flags)

        #expect(model.query.sort == .featured)
        await waitUntil { await callCount() == 3 }
        await tearDown(task)
    }
}

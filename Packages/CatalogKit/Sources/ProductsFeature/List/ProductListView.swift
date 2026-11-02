import CatalogAccessibility
import CatalogCore
import DesignSystem
import SwiftUI

struct ProductListView: View {
    @Bindable var model: ProductListModel
    @Binding var selection: ProductSummary?
    let currencyCode: String
    /// The split view keeps the selected card highlighted; a stack pushes and forgets it.
    let highlightsSelection: Bool

    @Environment(RemoteConfigStore.self) private var remoteConfig

    private typealias ID = AccessibilityID.ProductList

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.screenBackground)
            .navigationTitle(L10n.List.title)
            .searchable(text: $model.searchText, prompt: L10n.List.searchPrompt)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    categoryMenu
                    sortMenu
                }
            }
            .animation(Motion.standard, value: model.phase)
            .animation(Motion.standard, value: model.isOffline)
            .animation(Motion.standard, value: model.refreshError)
            .animation(Motion.standard, value: remoteConfig.flags)
            .task { await model.start() }
            .onChange(of: remoteConfig.flags, initial: true) { _, flags in
                model.apply(flags)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            scrolling {
                VStack(spacing: Spacing.s) {
                    ForEach(0..<Metrics.skeletonRows, id: \.self) { _ in ProductCardSkeleton() }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.List.loading)
                .accessibilityIdentifier(ID.loading)
            }
            .scrollDisabled(true)
            .transition(.opacity)
        case .failed(let error):
            stateWithBanners {
                StateView(
                    systemImage: error == .offline ? "wifi.slash" : "exclamationmark.triangle",
                    title: L10n.Error.title(error),
                    message: L10n.Error.message(error),
                    actionTitle: L10n.Error.retry,
                    actionIdentifier: ID.retryButton,
                    action: model.retry
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(ID.errorState)
            }
            .transition(.opacity)
        case .empty:
            stateWithBanners {
                emptyState
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(ID.emptyState)
            }
            .transition(.opacity)
        case .loaded:
            productList
                .transition(.opacity)
        }
    }

    private var productList: some View {
        scrolling {
            ForEach(model.products) { product in
                Button {
                    selection = product
                } label: {
                    ProductCard(
                        product: product,
                        flags: remoteConfig.flags,
                        currencyCode: currencyCode,
                        isSelected: highlightsSelection && selection?.id == product.id
                    )
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier(ID.row(product.id))
                .onAppear { model.loadMoreIfNeeded(after: product) }
            }
            pageFooter
        }
        .refreshable { await model.refresh() }
        .accessibilityIdentifier(ID.list)
    }

    /// Shared scroll container: cards on the grouped background, banners on top, no scroll bars.
    private func scrolling(@ViewBuilder _ rows: () -> some View) -> some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s) {
                banners
                rows()
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    /// Full-screen states keep the announcement and status banners above them.
    private func stateWithBanners(@ViewBuilder _ state: () -> some View) -> some View {
        VStack(spacing: Spacing.s) {
            banners
            Spacer(minLength: 0)
            state()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
    }

    @ViewBuilder
    private var pageFooter: some View {
        Group {
            switch model.pageState {
            case .loading:
                ProductCardSkeleton()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.List.pageLoading)
                    .accessibilityIdentifier(ID.pageLoading)
            case .failed:
                VStack(spacing: Spacing.s) {
                    Text(L10n.List.pageFailed)
                        .font(Typography.rowMeta)
                        .foregroundStyle(Palette.secondaryText)
                    Button(L10n.Error.retry, action: model.retryNextPage)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .accessibilityIdentifier(ID.pageRetryButton)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.l)
            case .idle, .exhausted:
                EmptyView()
            }
        }
        .transition(.opacity)
        .animation(Motion.standard, value: model.pageState)
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.isSearching {
            StateView(
                systemImage: "magnifyingglass",
                title: L10n.List.noResultsTitle,
                message: L10n.List.noResultsMessage(model.query.search)
            )
        } else if model.query.categorySlug != nil {
            StateView(
                systemImage: "square.grid.2x2",
                title: L10n.List.emptyCategoryTitle,
                message: L10n.List.emptyCategoryMessage,
                actionTitle: L10n.List.allCategories,
                action: { model.selectCategory(nil) }
            )
        } else {
            StateView(
                systemImage: "shippingbox",
                title: L10n.List.emptyTitle,
                message: L10n.List.emptyMessage,
                actionTitle: L10n.Error.retry,
                actionIdentifier: ID.retryButton,
                action: model.retry
            )
        }
    }

    @ViewBuilder
    private var banners: some View {
        if let announcement = remoteConfig.flags.announcement {
            Banner(systemImage: "megaphone", text: announcement, style: .neutral)
                .accessibilityIdentifier(ID.announcementBanner)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        if model.isOffline, model.phase == .loaded {
            Banner(systemImage: "wifi.slash", text: L10n.List.offlineBanner, style: .warning)
                .accessibilityIdentifier(ID.offlineBanner)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if model.refreshError != nil {
            Banner(systemImage: "exclamationmark.arrow.circlepath", text: L10n.List.refreshFailedBanner, style: .warning)
                .accessibilityIdentifier(ID.refreshErrorBanner)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker(L10n.List.sort, selection: Binding(get: { model.query.sort }, set: model.selectSort)) {
                ForEach(remoteConfig.flags.sortOptions, id: \.self) { option in
                    Text(L10n.Sort.title(option)).tag(option)
                }
            }
        } label: {
            Label(L10n.List.sort, systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier(ID.sortMenu)
    }

    private var categoryMenu: some View {
        Menu {
            Picker(L10n.List.category, selection: Binding(get: { model.query.categorySlug }, set: model.selectCategory)) {
                Text(L10n.List.allCategories).tag(String?.none)
                ForEach(model.categories) { category in
                    Text(category.name).tag(Optional(category.slug))
                }
            }
        } label: {
            Label(
                L10n.List.category,
                systemImage: model.query.categorySlug == nil
                    ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
            )
            .contentTransition(.symbolEffect(.replace))
        }
        .disabled(model.isSearching)
        .accessibilityHint(model.isSearching ? L10n.List.categoryDisabledWhileSearching : "")
        .accessibilityIdentifier(ID.categoryMenu)
    }
}

import CatalogAccessibility
import CatalogCore
import DesignSystem
import SwiftUI

struct ProductListView: View {
    @Bindable var model: ProductListModel
    @Binding var selection: ProductSummary?
    let currencyCode: String

    @Environment(RemoteConfigStore.self) private var remoteConfig

    private typealias ID = AccessibilityID.ProductList

    var body: some View {
        content
            .navigationTitle(L10n.List.title)
            .searchable(text: $model.searchText, prompt: L10n.List.searchPrompt)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    categoryMenu
                    sortMenu
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { banners }
            .animation(.default, value: model.isOffline)
            .animation(.default, value: model.refreshError)
            .task { await model.start() }
            .onChange(of: remoteConfig.flags, initial: true) { _, flags in
                model.apply(flags)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView(L10n.List.loading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(ID.loading)
        case .failed(let error):
            StateView(
                systemImage: error == .offline ? "wifi.slash" : "exclamationmark.triangle",
                title: L10n.Error.title(error),
                message: L10n.Error.message(error),
                actionTitle: L10n.Error.retry,
                actionIdentifier: ID.retryButton,
                action: model.retry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(ID.errorState)
        case .empty:
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(ID.emptyState)
        case .loaded:
            list
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(model.products) { product in
                NavigationLink(value: product) {
                    ProductRow(product: product, flags: remoteConfig.flags, currencyCode: currencyCode)
                }
                .accessibilityIdentifier(ID.row(product.id))
                .onAppear { model.loadMoreIfNeeded(after: product) }
            }
            pageFooter
        }
        .listStyle(.plain)
        .refreshable { await model.refresh() }
        .accessibilityIdentifier(ID.list)
    }

    @ViewBuilder
    private var pageFooter: some View {
        switch model.pageState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(L10n.List.pageLoading)
                .accessibilityIdentifier(ID.pageLoading)
                .listRowSeparator(.hidden)
        case .failed:
            VStack(spacing: Spacing.s) {
                Text(L10n.List.pageFailed)
                    .font(Typography.rowMeta)
                    .foregroundStyle(Palette.secondaryText)
                Button(L10n.Error.retry, action: model.retryNextPage)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(ID.pageRetryButton)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .listRowSeparator(.hidden)
        case .idle, .exhausted:
            EmptyView()
        }
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
        VStack(spacing: Spacing.s) {
            if let announcement = remoteConfig.flags.announcement {
                Banner(systemImage: "megaphone", text: announcement, style: .neutral)
                    .accessibilityIdentifier(ID.announcementBanner)
            }
            if model.isOffline, model.phase == .loaded {
                Banner(systemImage: "wifi.slash", text: L10n.List.offlineBanner, style: .warning)
                    .accessibilityIdentifier(ID.offlineBanner)
            } else if model.refreshError != nil {
                Banner(systemImage: "exclamationmark.arrow.circlepath", text: L10n.List.refreshFailedBanner, style: .warning)
                    .accessibilityIdentifier(ID.refreshErrorBanner)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.xs)
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
            Label(L10n.List.category, systemImage: "line.3.horizontal.decrease.circle")
        }
        .disabled(model.isSearching)
        .accessibilityHint(model.isSearching ? L10n.List.categoryDisabledWhileSearching : "")
        .accessibilityIdentifier(ID.categoryMenu)
    }
}

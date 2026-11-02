import CatalogAccessibility
import CatalogCore
import DesignSystem
import SwiftUI

/// Regular width (iPad, split screen): sidebar list and detail side by side.
/// Compact width (iPhone, slide over): one navigation stack. The list model survives the switch.
public struct CatalogRootView: View {
    @State private var listModel: ProductListModel
    @State private var selection: ProductSummary?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let dependencies: CatalogDependencies

    public init(dependencies: CatalogDependencies) {
        self.dependencies = dependencies
        _listModel = State(initialValue: ProductListModel(dependencies: dependencies))
    }

    public var body: some View {
        if horizontalSizeClass == .compact {
            NavigationStack {
                list(highlightsSelection: false)
                    .navigationDestination(item: $selection) { product in
                        detail(for: product)
                    }
            }
        } else {
            NavigationSplitView {
                list(highlightsSelection: true)
                    .navigationSplitViewColumnWidth(min: Metrics.sidebarMinWidth, ideal: Metrics.sidebarIdealWidth)
            } detail: {
                NavigationStack {
                    if let selection {
                        detail(for: selection)
                    } else {
                        StateView(
                            systemImage: "shippingbox",
                            title: L10n.Detail.placeholderTitle,
                            message: L10n.Detail.placeholderMessage
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.screenBackground)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier(AccessibilityID.ProductDetail.placeholder)
                    }
                }
            }
            // Balanced keeps the list beside the detail in portrait too, so a tap never hides behind an overlay.
            .navigationSplitViewStyle(.balanced)
        }
    }

    private func list(highlightsSelection: Bool) -> some View {
        ProductListView(
            model: listModel,
            selection: $selection,
            currencyCode: dependencies.currencyCode,
            highlightsSelection: highlightsSelection
        )
    }

    private func detail(for product: ProductSummary) -> some View {
        ProductDetailView(summary: product, service: dependencies.products, currencyCode: dependencies.currencyCode)
            .id(product.id)
            .transition(.opacity)
    }
}

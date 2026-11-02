import CatalogAccessibility
import CatalogCore
import DesignSystem
import SwiftUI

/// Split view on iPad and large iPhones in landscape, a navigation stack everywhere else.
public struct CatalogRootView: View {
    @State private var listModel: ProductListModel
    @State private var selection: ProductSummary?
    private let dependencies: CatalogDependencies

    public init(dependencies: CatalogDependencies) {
        self.dependencies = dependencies
        _listModel = State(initialValue: ProductListModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationSplitView {
            ProductListView(model: listModel, selection: $selection, currencyCode: dependencies.currencyCode)
                .navigationSplitViewColumnWidth(min: Metrics.sidebarMinWidth, ideal: Metrics.sidebarIdealWidth)
        } detail: {
            if let selection {
                ProductDetailView(summary: selection, service: dependencies.products, currencyCode: dependencies.currencyCode)
                    .id(selection.id)
            } else {
                StateView(
                    systemImage: "shippingbox",
                    title: L10n.Detail.placeholderTitle,
                    message: L10n.Detail.placeholderMessage
                )
                .accessibilityIdentifier(AccessibilityID.ProductDetail.placeholder)
            }
        }
    }
}

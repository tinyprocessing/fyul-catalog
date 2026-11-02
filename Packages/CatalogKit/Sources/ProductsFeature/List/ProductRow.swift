import CatalogCore
import DesignSystem
import SwiftUI

struct ProductRow: View {
    let product: ProductSummary
    let flags: FeatureFlags
    let currencyCode: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.m))
        layout {
            RemoteImage(url: product.thumbnail)
                .frame(width: Metrics.thumbnailSize, height: Metrics.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(product.title)
                    .font(Typography.rowTitle)
                    .lineLimit(2)
                if let brand = product.brand {
                    // Primary, not secondary: secondary text on the iPad sidebar background fails contrast.
                    Text(brand)
                        .font(Typography.rowMeta)
                }
                PriceText(
                    price: product.price,
                    discountPercentage: product.discountPercentage,
                    showsDiscount: flags.showsDiscounts,
                    currencyCode: currencyCode
                )
                HStack(spacing: Spacing.s) {
                    StockBadge(level: StockLevel(stock: product.stock, lowThreshold: flags.lowStockThreshold))
                    if let rating = product.rating { Rating(value: rating) }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

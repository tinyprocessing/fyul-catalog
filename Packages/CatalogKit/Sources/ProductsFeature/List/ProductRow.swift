import CatalogCore
import DesignSystem
import SwiftUI

/// One product in the list:
///
///     [image]  Title
///              Brand
///              $9.99  $11.16  −10%
///              [12 left]        ★ 4.5
struct ProductCard: View {
    let product: ProductSummary
    let flags: FeatureFlags
    let currencyCode: String
    let isSelected: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.m))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.m))
        layout {
            RemoteImage(url: product.thumbnail)
                .frame(width: Metrics.thumbnailSize, height: Metrics.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(product.title)
                    .font(Typography.rowTitle)
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let brand = product.brand {
                    Text(brand)
                        .font(Typography.rowMeta)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                }
                PriceText(
                    price: product.price,
                    discountPercentage: product.discountPercentage,
                    showsDiscount: flags.showsDiscounts,
                    currencyCode: currencyCode
                )
                .padding(.top, Spacing.xxs)
                StockAndRating(
                    level: StockLevel(stock: product.stock, lowThreshold: flags.lowStockThreshold),
                    rating: product.rating
                )
            }
        }
        .card(isSelected: isSelected, padding: Spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Same footprint as `ProductCard`, so content replaces it without a jump.
struct ProductCardSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            SkeletonBlock(width: Metrics.thumbnailSize, height: Metrics.thumbnailSize)
            VStack(alignment: .leading, spacing: Spacing.s) {
                SkeletonBlock(height: Spacing.l)
                SkeletonBlock(width: Metrics.skeletonTitleWidth, height: Spacing.m)
                SkeletonBlock(width: Metrics.thumbnailSize, height: Spacing.l)
            }
        }
        .card(padding: Spacing.m)
        .shimmering()
        .accessibilityHidden(true)
    }
}

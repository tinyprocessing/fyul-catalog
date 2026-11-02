import CatalogCore
import DesignSystem
import SwiftUI

struct PriceText: View {
    let price: Decimal
    let discountPercentage: Double?
    let showsDiscount: Bool
    let currencyCode: String
    var font: Font = Typography.price

    private var activeDiscount: Double? {
        guard showsDiscount, let discountPercentage, discountPercentage > 0, discountPercentage < 100 else { return nil }
        return discountPercentage
    }

    var body: some View {
        let format = Decimal.FormatStyle.Currency(code: currencyCode)
        // Never truncate a price: when space runs out the old price and badge move to a second line.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                current(format)
                discount(format)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                current(format)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) { discount(format) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(format: format))
    }

    private func current(_ format: Decimal.FormatStyle.Currency) -> some View {
        Text(price, format: format)
            .font(font)
            .lineLimit(1)
            .contentTransition(.numericText(value: NSDecimalNumber(decimal: price).doubleValue))
    }

    @ViewBuilder
    private func discount(_ format: Decimal.FormatStyle.Currency) -> some View {
        if let discount = activeDiscount {
            // The API price is already discounted; the original is derived for context.
            Text(originalPrice(discount: discount), format: format)
                .font(Typography.caption)
                .strikethrough()
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
            Badge(Self.percent(discount, negative: true), style: .positive)
        }
    }

    private func originalPrice(discount: Double) -> Decimal {
        let factor = Decimal(1 - discount / 100)
        var original = price / factor
        var rounded = Decimal()
        NSDecimalRound(&rounded, &original, 2, .plain)
        return rounded
    }

    private func accessibilityText(format: Decimal.FormatStyle.Currency) -> String {
        let current = price.formatted(format)
        guard let discount = activeDiscount else { return current }
        return L10n.Price.discounted(
            price: current,
            original: originalPrice(discount: discount).formatted(format),
            discount: Self.percent(discount, negative: false)
        )
    }

    private static func percent(_ value: Double, negative: Bool) -> String {
        let formatted = (value / 100).formatted(.percent.precision(.fractionLength(0)))
        return negative ? "−\(formatted)" : formatted
    }
}

struct StockBadge: View {
    let level: StockLevel

    var body: some View {
        switch level {
        case .outOfStock: Badge(L10n.Stock.outOfStock, style: .critical)
        case .low(let count): Badge(L10n.Stock.low(count), style: .warning)
        case .available(let count): Badge(L10n.Stock.available(count), style: .neutral)
        }
    }
}

struct Rating: View {
    let value: Double

    var body: some View {
        RatingView(value)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.rating(value.formatted(.number.precision(.fractionLength(1)))))
    }
}

/// Stock on the leading edge, rating on the trailing edge; stacked when large text needs the room.
struct StockAndRating: View {
    let level: StockLevel
    let rating: Double?
    var stockIdentifier = ""

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s) {
                badge
                Spacer(minLength: Spacing.s)
                ratingView
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                badge
                ratingView
            }
        }
    }

    private var badge: some View {
        StockBadge(level: level).accessibilityIdentifier(stockIdentifier)
    }

    @ViewBuilder
    private var ratingView: some View {
        if let rating { Rating(value: rating) }
    }
}

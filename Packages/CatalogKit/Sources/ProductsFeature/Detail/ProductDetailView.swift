import CatalogAccessibility
import CatalogCore
import DesignSystem
import SwiftUI

struct ProductDetailView: View {
    @State private var model: ProductDetailModel
    let currencyCode: String

    @Environment(RemoteConfigStore.self) private var remoteConfig
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private typealias ID = AccessibilityID.ProductDetail

    init(summary: ProductSummary, service: any ProductService, currencyCode: String) {
        _model = State(initialValue: ProductDetailModel(summary: summary, service: service))
        self.currencyCode = currencyCode
    }

    var body: some View {
        Group {
            if model.phase == .unavailable {
                StateView(
                    systemImage: "shippingbox.and.arrow.backward",
                    title: L10n.Detail.unavailableTitle,
                    message: L10n.Detail.unavailableMessage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(ID.unavailable)
            } else {
                ScrollView {
                    content
                        .frame(maxWidth: Metrics.readableWidth)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.l)
                }
                .accessibilityIdentifier(ID.root)
            }
        }
        .navigationTitle(model.summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        let header = VStack(alignment: .leading, spacing: Spacing.m) { summarySection }
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: Spacing.xl) {
                    gallery.frame(maxWidth: Metrics.galleryMaxWidth)
                    header
                }
            } else {
                gallery
                header
            }
            detailSections
        }
    }

    // MARK: Summary: available immediately from the list

    @ViewBuilder
    private var summarySection: some View {
        let detail = model.detail
        let summary = model.summary
        if let brand = detail?.brand ?? summary.brand {
            Text(brand)
                .font(Typography.rowMeta)
                .foregroundStyle(Palette.secondaryText)
        }
        Text(detail?.title ?? summary.title)
            .font(Typography.detailTitle)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(ID.title)
        PriceText(
            price: detail?.price ?? summary.price,
            discountPercentage: detail?.discountPercentage ?? summary.discountPercentage,
            showsDiscount: remoteConfig.flags.showsDiscounts,
            currencyCode: currencyCode,
            font: Typography.detailPrice
        )
        .accessibilityIdentifier(ID.price)
        HStack(spacing: Spacing.s) {
            StockBadge(level: StockLevel(stock: detail?.stock ?? summary.stock, lowThreshold: remoteConfig.flags.lowStockThreshold))
                .accessibilityIdentifier(ID.stock)
            if let rating = detail?.rating ?? summary.rating { Rating(value: rating) }
        }
    }

    @ViewBuilder
    private var gallery: some View {
        let images = model.detail?.images ?? []
        let urls = images.isEmpty ? [model.summary.thumbnail] : images.map(Optional.some)
        TabView {
            ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                RemoteImage(url: url, contentMode: .fit)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
        .frame(height: Metrics.galleryHeight)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.l))
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
    }

    // MARK: Full detail

    @ViewBuilder
    private var detailSections: some View {
        switch model.phase {
        case .loading:
            ProgressView(L10n.Detail.loading)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(ID.loading)
        case .failed(let error):
            VStack(spacing: Spacing.s) {
                Text(L10n.Detail.loadFailed).font(Typography.sectionTitle)
                Text(L10n.Error.message(error))
                    .font(Typography.rowMeta)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                Button(L10n.Error.retry) { Task { await model.load() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(ID.retryButton)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(ID.errorState)
        case .loaded(let detail):
            loadedSections(detail)
        case .unavailable:
            EmptyView()
        }
    }

    @ViewBuilder
    private func loadedSections(_ detail: ProductDetail) -> some View {
        if !detail.description.isEmpty {
            Section {
                Text(detail.description)
            } header: {
                sectionHeader(L10n.Detail.description)
            }
        }
        Section {
            facts(detail)
        } header: {
            sectionHeader(L10n.Detail.details)
        }
        if remoteConfig.flags.showsReviews {
            Section {
                reviews(detail.reviews)
            } header: {
                sectionHeader(L10n.Detail.reviews)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(ID.reviews)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.sectionTitle)
            .accessibilityAddTraits(.isHeader)
    }

    private func facts(_ detail: ProductDetail) -> some View {
        let rows: [(String, String?)] = [
            (L10n.Detail.sku, detail.sku),
            (L10n.Detail.stock, String(detail.stock)),
            (L10n.Detail.minimumOrder, detail.minimumOrderQuantity.map(L10n.Detail.units)),
            (L10n.Detail.category, detail.category.capitalized),
            (L10n.Detail.shipping, detail.shippingInformation),
            (L10n.Detail.warranty, detail.warrantyInformation),
            (L10n.Detail.returns, detail.returnPolicy),
        ]
        return VStack(spacing: Spacing.s) {
            ForEach(rows.filter { $0.1 != nil }, id: \.0) { title, value in
                LabeledContent(title, value: value ?? "")
                Divider()
            }
        }
        .font(Typography.rowMeta)
    }

    @ViewBuilder
    private func reviews(_ reviews: [ProductDetail.Review]) -> some View {
        if reviews.isEmpty {
            Text(L10n.Detail.noReviews).foregroundStyle(Palette.secondaryText)
        } else {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.Detail.reviewCount(reviews.count))
                    .font(Typography.rowMeta)
                    .foregroundStyle(Palette.secondaryText)
                ForEach(Array(reviews.enumerated()), id: \.offset) { _, review in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Rating(value: Double(review.rating))
                            Spacer()
                            Text(review.date, format: .dateTime.day().month().year())
                                .font(Typography.caption)
                                .foregroundStyle(Palette.secondaryText)
                        }
                        Text(review.comment)
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

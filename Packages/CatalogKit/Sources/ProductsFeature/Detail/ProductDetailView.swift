import CatalogAccessibility
import CatalogCore
import DesignSystem
import SwiftUI

struct ProductDetailView: View {
    @State private var model: ProductDetailModel
    @State private var galleryPage = 0
    @State private var galleryBackdrops: [Int: Color] = [:]
    let currencyCode: String

    @Environment(RemoteConfigStore.self) private var remoteConfig

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
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        hero
                        sections
                    }
                    .frame(maxWidth: Metrics.readableWidth)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.l)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier(ID.root)
            }
        }
        .background(Palette.screenBackground)
        .navigationTitle(model.summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.gentle, value: model.phase)
        .task { await model.load() }
    }

    // MARK: Hero: available immediately from the list

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            gallery
            summary.padding(Spacing.l)
        }
        .card(padding: 0)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
    }

    private var gallery: some View {
        let images = model.detail?.images ?? []
        let urls = images.isEmpty ? [model.summary.thumbnail] : images.map(Optional.some)
        return TabView(selection: $galleryPage) {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                RemoteImage(url: url, contentMode: .fit) { galleryBackdrops[index] = $0 }
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(height: Metrics.galleryHeight)
        .background(galleryBackdrops[galleryPage] ?? Palette.insetBackground)
        .animation(Motion.gentle, value: galleryPage)
    }

    private var summary: some View {
        let detail = model.detail
        let summary = model.summary
        return VStack(alignment: .leading, spacing: Spacing.s) {
            if let brand = detail?.brand ?? summary.brand {
                Text(brand.uppercased())
                    .font(Typography.caption.weight(.semibold))
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
            StockAndRating(
                level: StockLevel(stock: detail?.stock ?? summary.stock, lowThreshold: remoteConfig.flags.lowStockThreshold),
                rating: detail?.rating ?? summary.rating,
                stockIdentifier: ID.stock
            )
            .padding(.top, Spacing.xs)
        }
    }

    // MARK: Full detail

    @ViewBuilder
    private var sections: some View {
        switch model.phase {
        case .loading:
            sectionSkeleton
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.Detail.loading)
                .accessibilityIdentifier(ID.loading)
                .transition(.opacity)
        case .failed(let error):
            VStack(spacing: Spacing.m) {
                Image(systemName: "exclamationmark.triangle")
                    .font(Typography.detailTitle)
                    .foregroundStyle(Palette.warning)
                Text(L10n.Detail.loadFailed).font(Typography.sectionTitle)
                Text(L10n.Error.message(error))
                    .font(Typography.rowMeta)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                Button(L10n.Error.retry) { Task { await model.load() } }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier(ID.retryButton)
            }
            .frame(maxWidth: .infinity)
            .card()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(ID.errorState)
            .transition(.opacity)
        case .loaded(let detail):
            loadedSections(detail)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .unavailable:
            EmptyView()
        }
    }

    private var sectionSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            ForEach(0..<Metrics.skeletonSections, id: \.self) { _ in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SkeletonBlock(width: Metrics.skeletonTitleWidth, height: Spacing.l)
                    SkeletonBlock(height: Spacing.m)
                    SkeletonBlock(height: Spacing.m)
                    SkeletonBlock(width: Metrics.skeletonShortLineWidth, height: Spacing.m)
                }
                .card()
            }
        }
        .shimmering()
    }

    @ViewBuilder
    private func loadedSections(_ detail: ProductDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if !detail.description.isEmpty {
                section(L10n.Detail.description) {
                    Text(detail.description)
                        .font(Typography.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            section(L10n.Detail.details) { facts(detail) }
            if remoteConfig.flags.showsReviews {
                section(L10n.Detail.reviews, trailing: detail.reviews.isEmpty ? nil : L10n.Detail.reviewCount(detail.reviews.count)) {
                    reviews(detail.reviews)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(ID.reviews)
            }
        }
    }

    private func section(_ title: String, trailing: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Typography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(Typography.rowMeta)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            content()
        }
        .card()
    }

    private func facts(_ detail: ProductDetail) -> some View {
        let rows: [(String, String)] = [
            (L10n.Detail.sku, detail.sku),
            (L10n.Detail.stock, String(detail.stock)),
            (L10n.Detail.minimumOrder, detail.minimumOrderQuantity.map(L10n.Detail.units)),
            (L10n.Detail.category, detail.category.capitalized),
            (L10n.Detail.shipping, detail.shippingInformation),
            (L10n.Detail.warranty, detail.warrantyInformation),
            (L10n.Detail.returns, detail.returnPolicy),
        ].compactMap { title, value in value.map { (title, $0) } }
        return VStack(spacing: Spacing.m) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                LabeledContent(row.0) {
                    Text(row.1)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Palette.primaryText)
                }
                .font(Typography.rowMeta)
            }
        }
    }

    @ViewBuilder
    private func reviews(_ reviews: [ProductDetail.Review]) -> some View {
        if reviews.isEmpty {
            Text(L10n.Detail.noReviews)
                .font(Typography.rowMeta)
                .foregroundStyle(Palette.secondaryText)
        } else {
            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(Array(reviews.enumerated()), id: \.offset) { index, review in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(alignment: .center) {
                            StarsView(review.rating)
                            Spacer()
                            Text(review.date, format: .dateTime.day().month(.abbreviated).year())
                                .font(Typography.caption)
                                .foregroundStyle(Palette.secondaryText)
                        }
                        Text(review.comment)
                            .font(Typography.body)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(L10n.rating(String(review.rating))). \(review.comment). \(review.date.formatted(date: .abbreviated, time: .omitted))"
                    )
                }
            }
        }
    }
}

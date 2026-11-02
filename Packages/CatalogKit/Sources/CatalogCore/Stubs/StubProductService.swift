#if DEBUG
    import Foundation

    /// Deterministic backend for UI tests, Maestro flows and previews. Selected with `-uiTestScenario <name>`.
    public enum StubScenario: String, CaseIterable, Sendable {
        /// 45 products, paginated like the real API.
        case catalog
        case empty
        /// Every request fails with a server error.
        case serverError
        /// The first products request fails, the retry succeeds.
        case recoversAfterRetry
        /// The second page fails once, then loads.
        case pageFails
        /// Detail requests return 404, as if the product was removed.
        case productRemoved
        /// Every response takes three seconds.
        case slow
    }

    public actor StubProductService: ProductService {
        private let scenario: StubScenario
        private let catalog: [ProductSummary]
        private var failuresLeft: Int
        private var pageFailuresLeft = 1

        public init(scenario: StubScenario) {
            self.scenario = scenario
            self.catalog = scenario == .empty ? [] : StubCatalog.products
            self.failuresLeft = scenario == .recoversAfterRetry ? 1 : 0
        }

        public func products(for query: ProductQuery, skip: Int, limit: Int) async throws -> Page<ProductSummary> {
            try await simulateLatency()
            switch scenario {
            case .serverError:
                throw APIError.server(status: 500, retryAfter: nil)
            case .recoversAfterRetry where failuresLeft > 0:
                failuresLeft -= 1
                throw APIError.server(status: 503, retryAfter: nil)
            case .pageFails where skip > 0 && pageFailuresLeft > 0:
                pageFailuresLeft -= 1
                throw APIError.timedOut
            default:
                break
            }
            let matching = catalog.filter { product in
                if !query.search.isEmpty { return product.title.localizedCaseInsensitiveContains(query.search) }
                if let slug = query.categorySlug { return product.category == slug }
                return true
            }
            let sorted = matching.sorted(by: query.sort)
            let slice = sorted.dropFirst(skip).prefix(limit)
            return Page(items: Array(slice), total: sorted.count, skip: skip)
        }

        public func product(id: Int) async throws -> ProductDetail {
            try await simulateLatency()
            if scenario == .serverError { throw APIError.server(status: 500, retryAfter: nil) }
            if scenario == .productRemoved { throw APIError.notFound }
            guard let summary = catalog.first(where: { $0.id == id }) else { throw APIError.notFound }
            return StubCatalog.detail(for: summary)
        }

        public func categories() async throws -> [ProductCategory] {
            try await simulateLatency()
            return StubCatalog.categories
        }

        private func simulateLatency() async throws {
            try await Task.sleep(for: scenario == .slow ? .seconds(3) : .milliseconds(150))
        }
    }

    enum StubCatalog {
        static let categories = [
            ProductCategory(slug: "groceries", name: "Groceries"),
            ProductCategory(slug: "furniture", name: "Furniture"),
            ProductCategory(slug: "laptops", name: "Laptops"),
        ]

        static let products: [ProductSummary] = (1...45).map { id in
            let category = categories[(id - 1) % categories.count]
            return ProductSummary(
                id: id,
                title: "\(category.name) item \(id)",
                brand: id.isMultiple(of: 4) ? nil : "Brand \(id % 5)",
                category: category.slug,
                price: Decimal(id * 3) + Decimal(string: "0.99")!,
                discountPercentage: id.isMultiple(of: 3) ? 15 : nil,
                rating: Double(id % 5) + 0.5,
                stock: [0, 3, 25, 120][id % 4],
                thumbnail: nil
            )
        }

        static func detail(for summary: ProductSummary) -> ProductDetail {
            ProductDetail(
                id: summary.id,
                title: summary.title,
                description: "A reliable product for everyday use. Stock and pricing are refreshed from the catalog.",
                brand: summary.brand,
                category: summary.category,
                price: summary.price,
                discountPercentage: summary.discountPercentage,
                rating: summary.rating,
                stock: summary.stock,
                sku: "SKU-\(summary.id)",
                minimumOrderQuantity: 5,
                warrantyInformation: "1 year warranty",
                shippingInformation: "Ships in 2 days",
                returnPolicy: "30 days return policy",
                tags: [summary.category],
                reviews: [
                    .init(rating: 5, comment: "Great value", date: Date(timeIntervalSince1970: 1_760_000_000)),
                    .init(rating: 3, comment: "Does the job", date: Date(timeIntervalSince1970: 1_761_000_000)),
                ]
            )
        }
    }

    extension Array where Element == ProductSummary {
        func sorted(by option: SortOption) -> [ProductSummary] {
            switch option {
            case .featured: self
            case .priceLowToHigh: sorted { $0.price < $1.price }
            case .priceHighToLow: sorted { $0.price > $1.price }
            case .lowStockFirst: sorted { $0.stock < $1.stock }
            case .topRated: sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
            }
        }
    }
#endif

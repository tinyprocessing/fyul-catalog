import CatalogCore
import Foundation
import Testing

@Suite("Product query")
struct ProductQueryTests {
    private func query(_ endpoint: Endpoint) -> [String: String] {
        Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value ?? "") })
    }

    @Test func browsingAllProducts() {
        let endpoint = ProductQuery.all.endpoint(skip: 40, limit: 20)
        #expect(endpoint.path == "products")
        #expect(query(endpoint)["skip"] == "40")
        #expect(query(endpoint)["limit"] == "20")
        #expect(query(endpoint)["sortBy"] == nil)
    }

    @Test("Search wins over category: the API cannot combine them")
    func searchOverridesCategory() {
        let endpoint = ProductQuery(search: "phone", categorySlug: "laptops").endpoint(skip: 0, limit: 20)
        #expect(endpoint.path == "products/search")
        #expect(query(endpoint)["q"] == "phone")
    }

    @Test func categoryAndSort() {
        let endpoint = ProductQuery(categorySlug: "laptops", sort: .lowStockFirst).endpoint(skip: 0, limit: 20)
        #expect(endpoint.path == "products/category/laptops")
        #expect(query(endpoint)["sortBy"] == "stock")
        #expect(query(endpoint)["order"] == "asc")
    }

    @Test("The list only asks for the fields it shows")
    func selectsSummaryFields() {
        let fields = query(ProductQuery.all.endpoint(skip: 0, limit: 20))["select"]?.split(separator: ",").map(String.init)
        #expect(fields == ProductSummary.selectedFields)
    }
}

@Suite("Decoding")
struct DecodingTests {
    @Test("Detail decodes a real API payload, including fractional-second dates")
    func decodesDetail() throws {
        let detail = try JSONDecoder.api.decode(ProductDetail.self, from: fixtureData("product-detail"))
        #expect(detail.id == 1)
        #expect(detail.price == Decimal(string: "9.99"))
        #expect(detail.reviews.count == 3)
        #expect(detail.minimumOrderQuantity == 48)
    }

    @Test("A broken image URL is dropped instead of failing the product")
    func toleratesBrokenImages() throws {
        let json = #"{"id":2,"title":"T","category":"c","price":1,"images":["", "https://cdn.example.com/1.webp"]}"#
        let detail = try JSONDecoder.api.decode(ProductDetail.self, from: Data(json.utf8))
        #expect(detail.images.count == 1)
        #expect(detail.stock == 0)
    }

    @Test("Live service maps a broken payload to a decoding error")
    func liveServiceDecodingError() async {
        let client = MockHTTPClient([.success(Data("{}".utf8))])
        let service = LiveProductService(
            client: client,
            api: .init(baseURL: URL(string: "https://example.com")!, requestTimeout: .seconds(1), currencyCode: "USD")
        )
        await #expect(throws: APIError.decoding) {
            try await service.product(id: 1)
        }
    }
}

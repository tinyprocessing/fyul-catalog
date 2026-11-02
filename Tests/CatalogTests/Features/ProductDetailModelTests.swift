import CatalogCore
import Foundation
import ProductsFeature
import Testing

@MainActor
@Suite("Product detail")
struct ProductDetailModelTests {
    private let service = ControlledProductService()
    private let summary = ProductSummary.fixture(7, stock: 4)

    @Test("Loads the full product")
    func loads() async throws {
        let detail = ProductDetail(id: 7, title: "Fresh title", description: "", category: "groceries", price: 5, stock: 2)
        await service.setDetail(.success(detail))
        let model = ProductDetailModel(summary: summary, service: service)

        await model.load()

        #expect(model.detail == detail)
    }

    @Test("A removed product shows as unavailable, not as an error")
    func removedProduct() async {
        await service.setDetail(.failure(.notFound))
        let model = ProductDetailModel(summary: summary, service: service)

        await model.load()

        #expect(model.phase == .unavailable)
    }

    @Test("A network failure can be retried")
    func failureThenRetry() async {
        await service.setDetail(.failure(.timedOut))
        let model = ProductDetailModel(summary: summary, service: service)
        await model.load()
        #expect(model.phase == .failed(.timedOut))

        await service.setDetail(.success(ProductDetail(id: 7, title: "T", description: "", category: "c", price: 1, stock: 1)))
        await model.load()

        #expect(model.detail != nil)
    }
}

@Suite("Stock level")
struct StockLevelTests {
    @Test(arguments: [(0, StockLevel.outOfStock), (3, .low(3)), (10, .low(10)), (11, .available(11))])
    func thresholds(stock: Int, expected: StockLevel) {
        #expect(StockLevel(stock: stock, lowThreshold: 10) == expected)
    }
}

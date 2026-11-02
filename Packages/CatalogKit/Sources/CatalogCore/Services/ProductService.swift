import Foundation

public protocol ProductService: Sendable {
    func products(for query: ProductQuery, skip: Int, limit: Int) async throws -> Page<ProductSummary>
    func product(id: Int) async throws -> ProductDetail
    func categories() async throws -> [ProductCategory]
}

public struct LiveProductService: ProductService {
    private let client: any HTTPClient
    private let api: AppConfig.API
    private let decoder: JSONDecoder

    public init(client: any HTTPClient, api: AppConfig.API) {
        self.client = client
        self.api = api
        self.decoder = .api
    }

    public func products(for query: ProductQuery, skip: Int, limit: Int) async throws -> Page<ProductSummary> {
        let response: ProductsResponse = try await get(query.endpoint(skip: skip, limit: limit))
        return Page(items: response.products, total: response.total, skip: response.skip)
    }

    public func product(id: Int) async throws -> ProductDetail {
        try await get(Endpoint(path: "products/\(id)"))
    }

    public func categories() async throws -> [ProductCategory] {
        try await get(Endpoint(path: "products/categories"))
    }

    private func get<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await client.data(for: endpoint.request(baseURL: api.baseURL, timeout: api.requestTimeout))
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

private struct ProductsResponse: Decodable {
    let products: [ProductSummary]
    let total: Int
    let skip: Int
}

extension JSONDecoder {
    public static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
                return date
            }
            if let date = try? Date.ISO8601FormatStyle().parse(value) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unexpected date \(value)"))
        }
        return decoder
    }
}

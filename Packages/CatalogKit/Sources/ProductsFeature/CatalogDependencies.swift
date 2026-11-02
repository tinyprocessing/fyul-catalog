import CatalogCore
import Foundation

/// Everything the feature needs from the outside world. Tests and previews swap any part.
public struct CatalogDependencies: Sendable {
    public var products: any ProductService
    public var connectivity: any ConnectivityMonitor
    public var paging: AppConfig.Paging
    public var search: AppConfig.Search
    public var currencyCode: String
    public var sleep: @Sendable (Duration) async throws -> Void

    public init(
        products: any ProductService,
        connectivity: any ConnectivityMonitor,
        paging: AppConfig.Paging,
        search: AppConfig.Search,
        currencyCode: String,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.products = products
        self.connectivity = connectivity
        self.paging = paging
        self.search = search
        self.currencyCode = currencyCode
        self.sleep = sleep
    }
}

extension Error {
    var asAPIError: APIError {
        self as? APIError ?? .transport(code: URLError.unknown.rawValue)
    }
}

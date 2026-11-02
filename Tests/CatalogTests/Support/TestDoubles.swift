import CatalogCore
import Foundation
import Testing

extension ProductSummary {
    static func fixture(_ id: Int, stock: Int = 50) -> ProductSummary {
        ProductSummary(id: id, title: "Product \(id)", category: "groceries", price: Decimal(id), stock: stock)
    }
}

extension Page where Item == ProductSummary {
    static func of(_ ids: ClosedRange<Int>, total: Int, skip: Int = 0) -> Page {
        Page(items: ids.map { ProductSummary.fixture($0) }, total: total, skip: skip)
    }

    static let empty = Page(items: [], total: 0, skip: 0)
}

/// Every products request suspends until the test answers it, so tests decide the order of responses.
actor ControlledProductService: ProductService {
    struct Call: Equatable, Sendable {
        let query: ProductQuery
        let skip: Int
    }

    private(set) var calls: [Call] = []
    private var pending: [Int: CheckedContinuation<Page<ProductSummary>, any Error>] = [:]
    private var detailResult: Result<ProductDetail, APIError> = .failure(.notFound)

    func products(for query: ProductQuery, skip: Int, limit: Int) async throws -> Page<ProductSummary> {
        let index = calls.count
        calls.append(Call(query: query, skip: skip))
        return try await withCheckedThrowingContinuation { pending[index] = $0 }
    }

    func product(id: Int) async throws -> ProductDetail {
        try detailResult.get()
    }

    func categories() async throws -> [ProductCategory] {
        [ProductCategory(slug: "groceries", name: "Groceries")]
    }

    func respond(to index: Int, with page: Page<ProductSummary>) {
        pending.removeValue(forKey: index)?.resume(returning: page)
    }

    func fail(_ index: Int, with error: APIError) {
        pending.removeValue(forKey: index)?.resume(throwing: error)
    }

    func setDetail(_ result: Result<ProductDetail, APIError>) {
        detailResult = result
    }

    /// Releases requests the test never answered so no continuation leaks.
    func finishAll() {
        for continuation in pending.values { continuation.resume(throwing: CancellationError()) }
        pending.removeAll()
    }
}

final class ManualConnectivity: ConnectivityMonitor, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [AsyncStream<Bool>.Continuation] = []

    func isOnline() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            lock.withLock { continuations.append(continuation) }
        }
    }

    func send(_ online: Bool) {
        lock.withLock { continuations }.forEach { $0.yield(online) }
    }

    func finish() {
        lock.withLock { continuations }.forEach { $0.finish() }
    }
}

actor MockHTTPClient: HTTPClient {
    private var results: [Result<Data, APIError>]
    private(set) var requests: [URLRequest] = []

    init(_ results: [Result<Data, APIError>]) {
        self.results = results
    }

    func data(for request: URLRequest) async throws -> Data {
        requests.append(request)
        guard !results.isEmpty else { throw APIError.transport(code: -1) }
        return try results.removeFirst().get()
    }
}

actor SleepRecorder {
    private(set) var delays: [Duration] = []

    func record(_ delay: Duration) {
        delays.append(delay)
    }
}

/// Polls until `condition` holds. Models start work in their own tasks, so tests wait for observable state.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(2),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: @MainActor () async -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while await !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Condition not met within \(timeout)", sourceLocation: sourceLocation)
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

func fixtureData(_ name: String) throws -> Data {
    let url = try #require(Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private final class BundleToken {}

import Foundation
import os

/// One subsystem, one category per area. Read them with
/// `make logs` or Console.app filtered by subsystem `com.tinyprocessing.catalog`.
public enum Log {
    public static let subsystem = "com.tinyprocessing.catalog"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let products = Logger(subsystem: subsystem, category: "products")
    public static let remoteConfig = Logger(subsystem: subsystem, category: "remote-config")
    public static let connectivity = Logger(subsystem: subsystem, category: "connectivity")
}

/// Decorator that logs every attempt. Sits under `RetryingHTTPClient`, so retries show up as separate lines.
public struct LoggingHTTPClient: HTTPClient {
    private let base: any HTTPClient

    public init(base: any HTTPClient) {
        self.base = base
    }

    public func data(for request: URLRequest) async throws -> Data {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path() ?? "-"
        // Queries can carry what the user typed into search: logged, but redacted outside debugging.
        let query = request.url?.query() ?? ""
        let start = ContinuousClock.now
        do {
            let data = try await base.data(for: request)
            Log.network.debug(
                "\(method, privacy: .public) \(path, privacy: .public)?\(query, privacy: .private) → 2xx \(data.count) B in \(start.duration(to: .now), privacy: .public)"
            )
            return data
        } catch is CancellationError {
            Log.network.debug("\(method, privacy: .public) \(path, privacy: .public) cancelled")
            throw CancellationError()
        } catch {
            Log.network.error(
                "\(method, privacy: .public) \(path, privacy: .public)?\(query, privacy: .private) failed: \(String(describing: error), privacy: .public) in \(start.duration(to: .now), privacy: .public)"
            )
            throw error
        }
    }
}

import Foundation

public protocol HTTPClient: Sendable {
    /// Returns the body of a 2xx response or throws `APIError`.
    func data(for request: URLRequest) async throws -> Data
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw APIError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport(code: URLError.badServerResponse.rawValue) }
        if let error = APIError(response: http) { throw error }
        return data
    }
}

/// Decorator that repeats idempotent requests on transient failures.
public struct RetryingHTTPClient: HTTPClient {
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    private let base: any HTTPClient
    private let policy: RetryPolicy
    private let sleep: Sleep
    private let random: @Sendable () -> Double

    public init(
        base: any HTTPClient,
        policy: RetryPolicy,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        random: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }
    ) {
        self.base = base
        self.policy = policy
        self.sleep = sleep
        self.random = random
    }

    public func data(for request: URLRequest) async throws -> Data {
        var attempt = 1
        while true {
            try Task.checkCancellation()
            do {
                return try await base.data(for: request)
            } catch let error as APIError where error.isTransient && request.isIdempotent && attempt < policy.maxAttempts {
                guard let delay = policy.delay(afterAttempt: attempt, retryAfter: error.retryAfter, unitRandom: random()) else {
                    throw error
                }
                try await sleep(delay)
                attempt += 1
            }
        }
    }
}

extension URLRequest {
    var isIdempotent: Bool {
        ["GET", "HEAD", "OPTIONS", "PUT", "DELETE"].contains(httpMethod ?? "GET")
    }
}

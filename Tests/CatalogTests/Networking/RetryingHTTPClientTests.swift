import CatalogCore
import Foundation
import Testing

@Suite("Retrying HTTP client")
struct RetryingHTTPClientTests {
    private let policy = RetryPolicy(maxAttempts: 3, baseDelay: .milliseconds(500), maxDelay: .seconds(4), jitter: 0.2)
    private let request = URLRequest(url: URL(string: "https://example.com/products")!)

    private func makeClient(_ base: MockHTTPClient, sleeps: SleepRecorder) -> RetryingHTTPClient {
        RetryingHTTPClient(base: base, policy: policy, sleep: { await sleeps.record($0) }, random: { 0.5 })
    }

    @Test("Transient failures are retried with exponential backoff")
    func retriesTransientFailures() async throws {
        let base = MockHTTPClient([.failure(.server(status: 503, retryAfter: nil)), .failure(.timedOut), .success(Data("ok".utf8))])
        let sleeps = SleepRecorder()

        let data = try await makeClient(base, sleeps: sleeps).data(for: request)

        #expect(data == Data("ok".utf8))
        #expect(await base.requests.count == 3)
        #expect(await sleeps.delays == [.milliseconds(500), .seconds(1)])
    }

    @Test("Client errors fail at once", arguments: [APIError.notFound, .client(status: 400), .decoding, .offline])
    func doesNotRetryPermanentFailures(error: APIError) async {
        let base = MockHTTPClient([.failure(error), .success(Data())])

        await #expect(throws: error) {
            try await makeClient(base, sleeps: SleepRecorder()).data(for: request)
        }
        #expect(await base.requests.count == 1)
    }

    @Test("Gives up after the last attempt and surfaces the last error")
    func stopsAfterMaxAttempts() async {
        let base = MockHTTPClient(Array(repeating: .failure(.server(status: 500, retryAfter: nil)), count: 5))

        await #expect(throws: APIError.server(status: 500, retryAfter: nil)) {
            try await makeClient(base, sleeps: SleepRecorder()).data(for: request)
        }
        #expect(await base.requests.count == 3)
    }

    @Test("Waits for Retry-After when the server asks for it")
    func honoursRetryAfter() async throws {
        let base = MockHTTPClient([.failure(.rateLimited(retryAfter: .seconds(2))), .success(Data())])
        let sleeps = SleepRecorder()

        _ = try await makeClient(base, sleeps: sleeps).data(for: request)

        #expect(await sleeps.delays == [.seconds(2)])
    }

    @Test("Does not retry when Retry-After is longer than the policy allows")
    func givesUpOnLongRetryAfter() async {
        let base = MockHTTPClient([.failure(.rateLimited(retryAfter: .seconds(60))), .success(Data())])

        await #expect(throws: APIError.rateLimited(retryAfter: .seconds(60))) {
            try await makeClient(base, sleeps: SleepRecorder()).data(for: request)
        }
        #expect(await base.requests.count == 1)
    }

    @Test("Non-idempotent requests are never repeated")
    func doesNotRetryPost() async {
        var post = request
        post.httpMethod = "POST"
        let base = MockHTTPClient([.failure(.server(status: 503, retryAfter: nil)), .success(Data())])

        await #expect(throws: APIError.self) {
            try await makeClient(base, sleeps: SleepRecorder()).data(for: post)
        }
        #expect(await base.requests.count == 1)
    }

    @Test("Cancellation during backoff stops retrying")
    func cancellationStopsRetries() async {
        let base = MockHTTPClient([.failure(.timedOut), .success(Data())])
        let client = RetryingHTTPClient(base: base, policy: policy, sleep: { _ in throw CancellationError() })

        await #expect(throws: CancellationError.self) {
            try await client.data(for: request)
        }
        #expect(await base.requests.count == 1)
    }
}

@Suite("Retry policy")
struct RetryPolicyTests {
    private let policy = RetryPolicy(maxAttempts: 5, baseDelay: .seconds(1), maxDelay: .seconds(5), jitter: 0.2)

    @Test("Delay doubles per attempt and is capped")
    func exponentialAndCapped() {
        let delays = (1...4).map { policy.delay(afterAttempt: $0, unitRandom: 0.5) }
        #expect(delays == [.seconds(1), .seconds(2), .seconds(4), .seconds(5)])
    }

    @Test("Jitter stays within the configured fraction")
    func jitterBounds() {
        #expect(policy.delay(afterAttempt: 1, unitRandom: 0) == .milliseconds(800))
        #expect(policy.delay(afterAttempt: 1, unitRandom: 1) == .milliseconds(1200))
    }
}

@Suite("HTTP status mapping")
struct APIErrorMappingTests {
    private func response(_ status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    @Test func successIsNotAnError() {
        #expect(APIError(response: response(200)) == nil)
    }

    @Test func mapsStatusCodes() {
        #expect(APIError(response: response(404)) == .notFound)
        #expect(APIError(response: response(422)) == .client(status: 422))
        #expect(APIError(response: response(429, headers: ["Retry-After": "3"])) == .rateLimited(retryAfter: .seconds(3)))
        #expect(APIError(response: response(503)) == .server(status: 503, retryAfter: nil))
    }
}

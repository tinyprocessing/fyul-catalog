import Foundation

/// Exponential backoff with jitter. A server-provided `Retry-After` wins when it is longer.
public struct RetryPolicy: Sendable, Equatable {
    public var maxAttempts: Int
    public var baseDelay: Duration
    public var maxDelay: Duration
    /// Fraction of the delay that is randomised, e.g. 0.2 → ±20%.
    public var jitter: Double

    public init(maxAttempts: Int, baseDelay: Duration, maxDelay: Duration, jitter: Double) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    public static let none = RetryPolicy(maxAttempts: 1, baseDelay: .zero, maxDelay: .zero, jitter: 0)

    /// - Parameters:
    ///   - attempt: the attempt that just failed, starting at 1.
    ///   - unitRandom: a value in `0...1`, injected so tests are deterministic.
    /// - Returns: `nil` when the server asks to wait longer than `maxDelay`; retrying sooner would not help.
    public func delay(afterAttempt attempt: Int, retryAfter: Duration? = nil, unitRandom: Double) -> Duration? {
        let exponential = baseDelay * (1 << max(0, attempt - 1))
        let capped = min(exponential, maxDelay)
        let factor = 1 + jitter * (unitRandom * 2 - 1)
        let jittered = capped * factor
        guard let retryAfter else { return jittered }
        guard retryAfter <= maxDelay else { return nil }
        return max(jittered, retryAfter)
    }
}

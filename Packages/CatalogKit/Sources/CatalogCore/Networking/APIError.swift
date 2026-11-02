import Foundation

public enum APIError: Error, Equatable, Sendable {
    case offline
    case timedOut
    case notFound
    case rateLimited(retryAfter: Duration?)
    case server(status: Int, retryAfter: Duration?)
    case client(status: Int)
    case decoding
    case transport(code: Int)

    /// Worth repeating the same request: the failure is about the network or server load, not the request.
    public var isTransient: Bool {
        switch self {
        case .timedOut, .rateLimited, .server, .transport: true
        case .offline, .notFound, .client, .decoding: false
        }
    }

    public var retryAfter: Duration? {
        switch self {
        case .rateLimited(let retryAfter), .server(_, let retryAfter): retryAfter
        default: nil
        }
    }

    init(_ error: URLError) {
        switch error.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        case .timedOut:
            self = .timedOut
        default:
            self = .transport(code: error.code.rawValue)
        }
    }

    public init?(response: HTTPURLResponse) {
        let status = response.statusCode
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            .flatMap(Int.init)
            .map { Duration.seconds($0) }
        switch status {
        case 200..<300: return nil
        case 404: self = .notFound
        case 429: self = .rateLimited(retryAfter: retryAfter)
        case 400..<500: self = .client(status: status)
        default: self = .server(status: status, retryAfter: retryAfter)
        }
    }
}

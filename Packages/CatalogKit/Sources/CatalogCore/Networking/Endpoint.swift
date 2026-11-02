import Foundation

public struct Endpoint: Equatable, Sendable {
    public var path: String
    public var queryItems: [URLQueryItem]

    public init(path: String, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.queryItems = queryItems
    }

    public func request(baseURL: URL, timeout: Duration) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        var request = URLRequest(url: components.url!, timeoutInterval: timeout.timeInterval)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

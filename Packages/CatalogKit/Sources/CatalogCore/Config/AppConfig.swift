import Foundation

/// Static, build-time configuration. Everything tunable lives here instead of in call sites.
/// Environment-specific values (base URL, remote config URL) come from the xcconfig via Info.plist.
public struct AppConfig: Sendable {
    public struct API: Sendable {
        public var baseURL: URL
        public var requestTimeout: Duration
        public var currencyCode: String

        public init(baseURL: URL, requestTimeout: Duration, currencyCode: String) {
            self.baseURL = baseURL
            self.requestTimeout = requestTimeout
            self.currencyCode = currencyCode
        }
    }

    public struct Paging: Sendable {
        public var pageSize: Int
        /// How many rows before the end of the list the next page starts loading.
        public var prefetchDistance: Int

        public init(pageSize: Int, prefetchDistance: Int) {
            self.pageSize = pageSize
            self.prefetchDistance = prefetchDistance
        }
    }

    public struct Search: Sendable {
        public var debounce: Duration
        public var minimumQueryLength: Int

        public init(debounce: Duration, minimumQueryLength: Int) {
            self.debounce = debounce
            self.minimumQueryLength = minimumQueryLength
        }
    }

    public struct RemoteConfig: Sendable {
        public var url: URL?
        public var timeout: Duration

        public init(url: URL?, timeout: Duration) {
            self.url = url
            self.timeout = timeout
        }
    }

    public struct ImageCache: Sendable {
        public var memoryBytes: Int
        public var diskBytes: Int

        public init(memoryBytes: Int, diskBytes: Int) {
            self.memoryBytes = memoryBytes
            self.diskBytes = diskBytes
        }
    }

    public var api: API
    public var paging: Paging
    public var search: Search
    public var retry: RetryPolicy
    public var remoteConfig: RemoteConfig
    public var imageCache: ImageCache

    public init(
        api: API,
        paging: Paging,
        search: Search,
        retry: RetryPolicy,
        remoteConfig: RemoteConfig,
        imageCache: ImageCache
    ) {
        self.api = api
        self.paging = paging
        self.search = search
        self.retry = retry
        self.remoteConfig = remoteConfig
        self.imageCache = imageCache
    }
}

extension AppConfig {
    public enum InfoKey {
        public static let apiBaseURL = "APIBaseURL"
        public static let remoteConfigURL = "RemoteConfigURL"
    }

    public static func make(bundle: Bundle = .main) -> AppConfig {
        let baseURL = bundle.url(forInfoKey: InfoKey.apiBaseURL) ?? URL(string: "https://dummyjson.com")!
        return AppConfig(
            api: API(baseURL: baseURL, requestTimeout: .seconds(15), currencyCode: "USD"),
            paging: Paging(pageSize: 20, prefetchDistance: 5),
            search: Search(debounce: .milliseconds(350), minimumQueryLength: 2),
            retry: RetryPolicy(maxAttempts: 3, baseDelay: .milliseconds(500), maxDelay: .seconds(4), jitter: 0.2),
            remoteConfig: RemoteConfig(url: bundle.url(forInfoKey: InfoKey.remoteConfigURL), timeout: .seconds(5)),
            imageCache: ImageCache(memoryBytes: 50 * 1024 * 1024, diskBytes: 200 * 1024 * 1024)
        )
    }
}

extension Bundle {
    fileprivate func url(forInfoKey key: String) -> URL? {
        guard let value = object(forInfoDictionaryKey: key) as? String, !value.isEmpty else { return nil }
        return URL(string: value)
    }
}

extension Duration {
    public var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}

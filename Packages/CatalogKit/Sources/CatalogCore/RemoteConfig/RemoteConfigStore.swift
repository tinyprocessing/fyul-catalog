import Foundation
import Observation

public protocol RemoteConfigSource: Sendable {
    func fetch() async throws -> FeatureFlags
}

public protocol FlagsCache: Sendable {
    func load() -> FeatureFlags?
    func save(_ flags: FeatureFlags)
}

/// Fetches flags from a static JSON file. Any HTTP host works: the repo uses a raw GitHub URL.
public struct URLRemoteConfigSource: RemoteConfigSource {
    private let url: URL
    private let timeout: Duration
    private let client: any HTTPClient

    public init(url: URL, timeout: Duration, client: any HTTPClient) {
        self.url = url
        self.timeout = timeout
        self.client = client
    }

    public func fetch() async throws -> FeatureFlags {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout.timeInterval)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await client.data(for: request)
        return try JSONDecoder().decode(FeatureFlags.self, from: data)
    }
}

public struct UserDefaultsFlagsCache: FlagsCache, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "remoteConfig.flags") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> FeatureFlags? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(FeatureFlags.self, from: $0) }
    }

    public func save(_ flags: FeatureFlags) {
        defaults.set(try? JSONEncoder().encode(flags), forKey: key)
    }
}

/// Source of truth for flags in the UI. Order: last good fetch → bundled defaults.
/// A failed fetch never downgrades flags that are already applied.
@MainActor
@Observable
public final class RemoteConfigStore {
    public private(set) var flags: FeatureFlags
    @ObservationIgnored private let source: (any RemoteConfigSource)?
    @ObservationIgnored private let cache: any FlagsCache
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    public init(source: (any RemoteConfigSource)?, cache: any FlagsCache, defaults: FeatureFlags = .defaults) {
        self.source = source
        self.cache = cache
        self.flags = cache.load() ?? defaults
    }

    /// Safe to call on every foreground: concurrent calls share one request.
    public func refresh() async {
        if let refreshTask { return await refreshTask.value }
        guard let source else { return }
        let task = Task { [cache] in
            do {
                let fetched = try await source.fetch()
                cache.save(fetched)
                guard fetched != flags else { return }
                Log.remoteConfig.info("Applied new flags: \(String(describing: fetched), privacy: .public)")
                flags = fetched
            } catch {
                Log.remoteConfig.error("Fetch failed, keeping current flags: \(String(describing: error), privacy: .public)")
            }
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }
}

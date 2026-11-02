import CatalogCore
import Foundation
import Testing

@Suite("Feature flags decoding")
struct FeatureFlagsTests {
    private func decode(_ json: String) throws -> FeatureFlags {
        try JSONDecoder().decode(FeatureFlags.self, from: Data(json.utf8))
    }

    @Test func emptyPayloadUsesDefaults() throws {
        #expect(try decode("{}") == .defaults)
    }

    @Test("A wrong type for one key does not break the others")
    func malformedValueFallsBack() throws {
        let flags = try decode(#"{"lowStockThreshold": "ten", "showsReviews": false}"#)
        #expect(flags.lowStockThreshold == FeatureFlags.defaults.lowStockThreshold)
        #expect(flags.showsReviews == false)
    }

    @Test("Unknown sort options are dropped and featured is always kept")
    func sortOptionsAreSanitised() throws {
        let flags = try decode(#"{"sortOptions": ["topRated", "newest"]}"#)
        #expect(flags.sortOptions == [.featured, .topRated])
    }

    @Test func negativeThresholdIsClamped() throws {
        #expect(try decode(#"{"lowStockThreshold": -5}"#).lowStockThreshold == 0)
    }

    @Test func blankAnnouncementIsHidden() throws {
        #expect(try decode(#"{"announcement": "   "}"#).announcement == nil)
    }
}

@MainActor
@Suite("Remote config store")
struct RemoteConfigStoreTests {
    final class MemoryCache: FlagsCache, @unchecked Sendable {
        var stored: FeatureFlags?
        init(_ stored: FeatureFlags? = nil) { self.stored = stored }
        func load() -> FeatureFlags? { stored }
        func save(_ flags: FeatureFlags) { stored = flags }
    }

    actor StubSource: RemoteConfigSource {
        private let result: Result<FeatureFlags, APIError>
        private(set) var fetches = 0

        init(_ result: Result<FeatureFlags, APIError>) {
            self.result = result
        }

        func fetch() async throws -> FeatureFlags {
            fetches += 1
            try await Task.sleep(for: .milliseconds(20))
            return try result.get()
        }
    }

    private var remote: FeatureFlags {
        var flags = FeatureFlags.defaults
        flags.lowStockThreshold = 3
        return flags
    }

    @Test("Starts from the cached config before any request")
    func startsFromCache() {
        let store = RemoteConfigStore(source: nil, cache: MemoryCache(remote))
        #expect(store.flags == remote)
    }

    @Test("A successful fetch is applied and cached")
    func appliesFetchedFlags() async {
        let cache = MemoryCache()
        let store = RemoteConfigStore(source: StubSource(.success(remote)), cache: cache)

        await store.refresh()

        #expect(store.flags == remote)
        #expect(cache.stored == remote)
    }

    @Test("A failed fetch keeps the last good config")
    func failureKeepsCurrentFlags() async {
        let store = RemoteConfigStore(source: StubSource(.failure(.offline)), cache: MemoryCache(remote))

        await store.refresh()

        #expect(store.flags == remote)
    }

    @Test("Concurrent refreshes share one request")
    func refreshesAreCoalesced() async {
        let source = StubSource(.success(remote))
        let store = RemoteConfigStore(source: source, cache: MemoryCache())

        async let first: Void = store.refresh()
        async let second: Void = store.refresh()
        _ = await (first, second)

        #expect(await source.fetches == 1)
    }
}

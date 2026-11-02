import CatalogCore
import Foundation
import ProductsFeature

/// Composition root: the only place that decides which implementations the app runs with.
@MainActor
struct AppEnvironment {
    let dependencies: CatalogDependencies
    let remoteConfig: RemoteConfigStore

    static func make(config: AppConfig = .make(), arguments: LaunchArguments = LaunchArguments()) -> AppEnvironment {
        #if DEBUG
            if let scenario = arguments.stubScenario {
                return stubbed(scenario, config: config, arguments: arguments)
            }
        #endif
        return live(config: config)
    }

    private static func live(config: AppConfig) -> AppEnvironment {
        URLCache.shared = URLCache(memoryCapacity: config.imageCache.memoryBytes, diskCapacity: config.imageCache.diskBytes)
        let transport = URLSessionHTTPClient()
        let client = RetryingHTTPClient(base: LoggingHTTPClient(base: transport), policy: config.retry)
        let remoteSource = config.remoteConfig.url.map {
            URLRemoteConfigSource(url: $0, timeout: config.remoteConfig.timeout, client: transport)
        }
        return AppEnvironment(
            dependencies: CatalogDependencies(
                products: LiveProductService(client: client, api: config.api),
                connectivity: PathConnectivityMonitor(),
                paging: config.paging,
                search: config.search,
                currencyCode: config.api.currencyCode
            ),
            remoteConfig: RemoteConfigStore(source: remoteSource, cache: UserDefaultsFlagsCache())
        )
    }

    #if DEBUG
        /// UI tests and Maestro: no network, flags from launch arguments.
        private static func stubbed(_ scenario: StubScenario, config: AppConfig, arguments: LaunchArguments) -> AppEnvironment {
            Log.app.notice("Stubbed backend: \(scenario.rawValue, privacy: .public)")
            var flags = FeatureFlags.defaults
            if let threshold = arguments.lowStockThreshold { flags.lowStockThreshold = threshold }
            if let announcement = arguments.announcement { flags.announcement = announcement }
            let isolatedDefaults = UserDefaults(suiteName: "ui-tests") ?? .standard
            isolatedDefaults.removePersistentDomain(forName: "ui-tests")
            return AppEnvironment(
                dependencies: CatalogDependencies(
                    products: StubProductService(scenario: scenario),
                    connectivity: AlwaysOnlineMonitor(),
                    paging: config.paging,
                    search: config.search,
                    currencyCode: config.api.currencyCode
                ),
                remoteConfig: RemoteConfigStore(source: nil, cache: UserDefaultsFlagsCache(defaults: isolatedDefaults), defaults: flags)
            )
        }
    #endif
}

/// `-uiTestScenario catalog` style arguments land in `UserDefaults` via the argument domain.
struct LaunchArguments {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    #if DEBUG
        var stubScenario: StubScenario? {
            defaults.string(forKey: "uiTestScenario").flatMap(StubScenario.init(rawValue:))
        }
    #endif

    var lowStockThreshold: Int? {
        defaults.object(forKey: "lowStockThreshold") == nil ? nil : defaults.integer(forKey: "lowStockThreshold")
    }

    var announcement: String? {
        defaults.string(forKey: "announcement")
    }
}

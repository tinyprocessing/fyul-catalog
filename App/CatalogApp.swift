import CatalogCore
import ProductsFeature
import SwiftUI

@main
struct CatalogApp: App {
    @State private var environment = AppEnvironment.make()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CatalogRootView(dependencies: environment.dependencies)
                .environment(environment.remoteConfig)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { await environment.remoteConfig.refresh() }
        }
    }
}

import Foundation
import Network

public protocol ConnectivityMonitor: Sendable {
    /// Emits the current state first, then every change. Each call gets its own stream.
    func isOnline() -> AsyncStream<Bool>
}

public struct PathConnectivityMonitor: ConnectivityMonitor {
    public init() {}

    public func isOnline() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                Log.connectivity.info("Path \(path.status == .satisfied ? "online" : "offline", privacy: .public)")
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "connectivity.monitor"))
        }
    }
}

public struct AlwaysOnlineMonitor: ConnectivityMonitor {
    public init() {}

    public func isOnline() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.yield(true)
        }
    }
}

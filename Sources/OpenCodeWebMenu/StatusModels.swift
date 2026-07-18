import Foundation

struct StatusSnapshot: Sendable {
    let openCodeHealthy: Bool
    let serviceRunning: Bool
    let tailscaleRunning: Bool
    let remoteProxyEnabled: Bool
    let diagnostic: String?

    static let unavailable = StatusSnapshot(
        openCodeHealthy: false,
        serviceRunning: false,
        tailscaleRunning: false,
        remoteProxyEnabled: false,
        diagnostic: nil
    )
}

struct TailscaleStatus: Decodable {
    let BackendState: String?
}

struct ServeConfiguration: Decodable {
    let Web: [String: ServeEndpoint]?
}

struct ServeEndpoint: Decodable {
    let Handlers: [String: ServeHandler]
}

struct ServeHandler: Decodable {
    let Proxy: String?
}

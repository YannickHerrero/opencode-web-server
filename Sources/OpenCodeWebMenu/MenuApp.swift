import AppKit
import Foundation

@main
@MainActor
enum OpenCodeWebMenu {
    private static let delegate = MenuAppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}

@MainActor
private final class MenuAppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var status = StatusSnapshot.unavailable
    private var isUpdatingRemoteAccess = false
    private var actionMessage: String?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.title = "OC"
        statusItem.button?.image = statusImage(named: "terminal.fill", description: "OpenCode Status")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.setAccessibilityLabel("OpenCode Status")
        statusItem.button?.toolTip = "OpenCode status is loading"
        rebuildMenu()
        refreshStatus()
        refreshTimer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(refreshStatus), userInfo: nil, repeats: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    @objc private func refreshStatus() {
        Task { @MainActor [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                StatusChecker.check()
            }.value
            self?.apply(snapshot)
        }
    }

    @objc private func toggleRemoteAccess() {
        guard !isUpdatingRemoteAccess else { return }

        let willEnable = !status.remoteProxyEnabled
        isUpdatingRemoteAccess = true
        actionMessage = willEnable ? "Restoring tailnet access..." : "Pausing tailnet access..."
        rebuildMenu()

        let arguments = willEnable
            ? ["serve", "--bg", "--yes", "4096"]
            : ["serve", "--yes", "--https=443", "off"]

        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .utility) {
                CommandRunner.run(StatusChecker.tailscalePath, arguments: arguments)
            }.value

            guard let self else { return }
            self.isUpdatingRemoteAccess = false
            if result.succeeded {
                self.actionMessage = willEnable ? "Tailnet access restored." : "Tailnet access paused."
            } else if result.timedOut {
                self.actionMessage = "Tailscale Serve did not respond."
            } else {
                let error = result.error.trimmingCharacters(in: .whitespacesAndNewlines)
                self.actionMessage = error.isEmpty ? "Tailscale Serve update failed." : error
            }
            self.refreshStatus()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func apply(_ snapshot: StatusSnapshot) {
        status = snapshot
        let fullyAvailable = snapshot.openCodeHealthy && snapshot.serviceRunning && snapshot.tailscaleRunning && snapshot.remoteProxyEnabled
        statusItem.button?.image = statusImage(
            named: fullyAvailable ? "terminal.fill" : "exclamationmark.triangle.fill",
            description: "OpenCode Status"
        )
        statusItem.button?.toolTip = tooltip(for: snapshot)
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(statusRow(title: "OpenCode", value: status.openCodeHealthy ? "Healthy" : "Unavailable", healthy: status.openCodeHealthy))
        menu.addItem(statusRow(title: "LaunchAgent", value: status.serviceRunning ? "Running" : "Stopped", healthy: status.serviceRunning))
        menu.addItem(statusRow(title: "Tailscale", value: status.tailscaleRunning ? "Running" : "Unavailable", healthy: status.tailscaleRunning))
        menu.addItem(statusRow(title: "Tailnet access", value: status.remoteProxyEnabled ? "Active" : "Paused", healthy: status.remoteProxyEnabled))

        if let actionMessage {
            menu.addItem(NSMenuItem.separator())
            let message = NSMenuItem(title: actionMessage, action: nil, keyEquivalent: "")
            message.isEnabled = false
            menu.addItem(message)
        }

        if let diagnostic = status.diagnostic {
            menu.addItem(NSMenuItem.separator())
            let message = NSMenuItem(title: diagnostic, action: nil, keyEquivalent: "")
            message.isEnabled = false
            menu.addItem(message)
        }

        menu.addItem(NSMenuItem.separator())
        let remoteAccessItem = NSMenuItem(
            title: isUpdatingRemoteAccess ? "Updating Tailnet Access..." : (status.remoteProxyEnabled ? "Pause Tailnet Access" : "Resume Tailnet Access"),
            action: #selector(toggleRemoteAccess),
            keyEquivalent: ""
        )
        remoteAccessItem.target = self
        remoteAccessItem.isEnabled = !isUpdatingRemoteAccess
        menu.addItem(remoteAccessItem)

        let refreshItem = NSMenuItem(title: "Refresh Status", action: #selector(refreshStatus), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit OpenCode Status", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func statusRow(title: String, value: String, healthy: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: "\(title): \(value)", action: nil, keyEquivalent: "")
        item.image = statusImage(named: healthy ? "checkmark.circle.fill" : "xmark.circle.fill")
        item.isEnabled = false
        return item
    }

    private func statusImage(named name: String, description: String? = nil) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        image?.isTemplate = true
        return image
    }

    private func tooltip(for snapshot: StatusSnapshot) -> String {
        let server = snapshot.openCodeHealthy ? "healthy" : "unavailable"
        let remote = snapshot.remoteProxyEnabled ? "active" : "paused"
        return "OpenCode: \(server). Tailnet access: \(remote)."
    }
}

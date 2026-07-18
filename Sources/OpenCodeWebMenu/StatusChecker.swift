import Darwin
import Foundation

struct CommandResult: Sendable {
    let output: String
    let error: String
    let exitStatus: Int32
    let timedOut: Bool

    var succeeded: Bool {
        exitStatus == 0 && !timedOut
    }
}

enum CommandRunner {
    static func run(_ executable: String, arguments: [String], timeout: TimeInterval = 5) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let completion = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { _ in completion.signal() }

        do {
            try process.run()
        } catch {
            return CommandResult(output: "", error: error.localizedDescription, exitStatus: -1, timedOut: false)
        }

        let timedOut = completion.wait(timeout: .now() + timeout) == .timedOut
        if timedOut {
            process.terminate()
            process.waitUntilExit()
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(output: output, error: error, exitStatus: process.terminationStatus, timedOut: timedOut)
    }
}

enum StatusChecker {
    static let localHealthURL = "http://127.0.0.1:4096/global/health"
    static let localProxyURL = "http://127.0.0.1:4096"
    static let serviceLabel = "com.yannickherrero.opencode-web"
    static let tailscalePath = "/opt/homebrew/bin/tailscale"

    static func check() -> StatusSnapshot {
        let health = CommandRunner.run(
            "/usr/bin/curl",
            arguments: ["--max-time", "3", "--fail", "--silent", localHealthURL]
        )
        let service = CommandRunner.run(
            "/bin/launchctl",
            arguments: ["print", "gui/\(getuid())/\(serviceLabel)"]
        )
        let tailscale = CommandRunner.run(tailscalePath, arguments: ["status", "--json"])
        let serve = CommandRunner.run(tailscalePath, arguments: ["serve", "status", "--json"])

        let failures = [
            failureDescription("OpenCode", result: health),
            failureDescription("launchd", result: service),
            failureDescription("Tailscale", result: tailscale),
            failureDescription("Tailscale Serve", result: serve),
        ].compactMap { $0 }

        return StatusSnapshot(
            openCodeHealthy: openCodeHealthy(from: health),
            serviceRunning: service.succeeded && service.output.contains("state = running"),
            tailscaleRunning: tailscaleRunning(from: tailscale),
            remoteProxyEnabled: remoteProxyEnabled(from: serve),
            diagnostic: failures.isEmpty ? nil : failures.joined(separator: "\n")
        )
    }

    static func openCodeHealthy(from result: CommandResult) -> Bool {
        result.succeeded && result.output.contains("\"healthy\":true")
    }

    static func tailscaleRunning(from result: CommandResult) -> Bool {
        guard result.succeeded, let status = try? JSONDecoder().decode(TailscaleStatus.self, from: Data(result.output.utf8)) else {
            return false
        }
        return status.BackendState == "Running"
    }

    static func remoteProxyEnabled(from result: CommandResult) -> Bool {
        guard result.succeeded, let configuration = try? JSONDecoder().decode(ServeConfiguration.self, from: Data(result.output.utf8)) else {
            return false
        }
        return configuration.Web?.values.contains { endpoint in
            endpoint.Handlers.values.contains { $0.Proxy == localProxyURL }
        } ?? false
    }

    private static func failureDescription(_ name: String, result: CommandResult) -> String? {
        guard !result.succeeded else { return nil }
        if result.timedOut {
            return "\(name) check timed out."
        }
        let error = result.error.trimmingCharacters(in: .whitespacesAndNewlines)
        return error.isEmpty ? "\(name) check failed." : "\(name): \(error)"
    }
}

import Foundation
import Network
import UIKit

/// Local HTTP TCP server that listens for widget action commands on the LAN.
///
/// Background/locked-screen lifecycle:
///   - UIBackgroundModes: voip (Info.plist) keeps the listening socket alive at
///     the kernel level. The app process is fully suspended between connections;
///     the kernel wakes it only when a TCP packet arrives.
///   - Each incoming connection acquires its own background task so the app is
///     guaranteed execution time to run the action after the voip wakeup fires.
///     The token is held open until UIApplication.open() / the shortcut finishes,
///     then released — preventing iOS from suspending the app mid-execution.
///   - NWPathMonitor tears down the listener the moment Wi-Fi disconnects.
final class LocalActionServer {
    static let shared = LocalActionServer()

    /// Serial queue at .background QoS. Signals the CPU scheduler to stay at
    /// a low-power frequency while idle between packets.
    private let serverQueue = DispatchQueue(label: "com.app.serverQueue", qos: .background)

    private var listener: NWListener?
    private var pathMonitor: NWPathMonitor?

    private init() {}

    var isRunning: Bool { listener != nil }

    // MARK: - Public API

    func start() {
        guard !SharedStorage.shared.allowedSSID.isEmpty else { stop(); return }
        startPathMonitor()
    }

    func stop() {
        pathMonitor?.cancel()
        pathMonitor = nil
        stopListener()
    }

    // MARK: - Wi-Fi path monitor

    private func startPathMonitor() {
        pathMonitor?.cancel()
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.startListenerIfNeeded()
                } else {
                    self?.stopListener()
                }
            }
        }
        monitor.start(queue: serverQueue)
    }

    private func startListenerIfNeeded() {
        guard !SharedStorage.shared.allowedSSID.isEmpty else { stopListener(); return }
        guard listener == nil else { return }
        startListener()
    }

    // MARK: - Listener lifecycle

    private func startListener() {
        // allowedSSID and serverPort live in UserDefaults.standard — always readable
        // regardless of device lock state; no Keychain decryption occurs here.
        let portNumber = UInt16(clamping: SharedStorage.shared.serverPort)
        let port = NWEndpoint.Port(rawValue: portNumber) ?? 8080
        guard let listener = try? NWListener(using: .tcp, on: port) else { return }
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.listener = nil
            default: break
            }
        }
        // No listener-level background task needed: voip background mode owns the
        // socket between connections. Per-connection tasks cover action execution.
        listener.start(queue: serverQueue)
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Per-connection background task

    /// Wraps a UIBackgroundTaskIdentifier so all closures for a single connection
    /// can end it safely and exactly once.
    private final class TaskBox {
        var id: UIBackgroundTaskIdentifier = .invalid
        func end() {
            let t = id
            guard t != .invalid else { return }
            id = .invalid
            UIApplication.shared.endBackgroundTask(t)
        }
    }

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        // Acquire a per-connection background task immediately on wakeup.
        // This window (~30s) covers the entire receive → action → open-URL path.
        let task = TaskBox()
        task.id = UIApplication.shared.beginBackgroundTask(withName: "RemoteCommand") {
            connection.cancel()
            task.end()
        }

        connection.start(queue: serverQueue)

        // 5-second receive timeout: cancel idle connections and release the task.
        let timeout = DispatchWorkItem {
            connection.cancel()
            task.end()
        }
        serverQueue.asyncAfter(deadline: .now() + 5, execute: timeout)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            timeout.cancel()
            guard let data, let request = String(data: data, encoding: .utf8) else {
                self?.send(status: 400, body: "Bad Request", to: connection)
                task.end()
                return
            }
            self?.process(request: request, connection: connection, task: task)
        }
    }

    private func process(request: String, connection: NWConnection, task: TaskBox) {
        let firstLine = request.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            send(status: 405, body: "Method Not Allowed", to: connection)
            task.end()
            return
        }

        guard let url = URL(string: "http://localhost\(parts[1])"),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.path == "/execute-widget-action" else {
            send(status: 404, body: "Not Found", to: connection)
            task.end()
            return
        }

        guard let commandID = comps.queryItems?.first(where: { $0.name == "id" })?.value else {
            send(status: 400, body: "Missing id parameter", to: connection)
            task.end()
            return
        }

        // pushCommandEntries stored with kSecAttrAccessibleAfterFirstUnlock —
        // readable after first device unlock regardless of screen-lock state.
        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else {
            send(status: 404, body: "Command not found: \(commandID)", to: connection)
            task.end()
            return
        }

        // Dispatch the action, then release the background task only AFTER it
        // finishes. This keeps iOS from suspending the app between the voip
        // wakeup and UIApplication.open() / the shortcut completing.
        Task { @MainActor in
            try? await ActionExecutionService.shared.execute(action: entry.action)
            task.end()
        }
        send(status: 200, body: "OK: \(entry.label)", to: connection)
    }

    private func send(status: Int, body: String, to connection: NWConnection) {
        let text: String
        switch status {
        case 200: text = "OK"
        case 400: text = "Bad Request"
        case 404: text = "Not Found"
        case 405: text = "Method Not Allowed"
        default:  text = "Error"
        }
        let response = "HTTP/1.1 \(status) \(text)\r\nContent-Length: \(body.utf8.count)\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n\(body)"
        // Cancel the connection the instant the last byte is acknowledged.
        connection.send(content: Data(response.utf8),
                        completion: .contentProcessed { _ in connection.cancel() })
    }
}

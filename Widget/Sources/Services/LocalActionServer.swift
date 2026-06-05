import Foundation
import Network
import UIKit

/// Local HTTP TCP server that listens for widget action commands on the LAN.
///
/// Background/locked-screen lifecycle:
///   - UIBackgroundModes: voip keeps the socket alive at the kernel level.
///   - pendingRemoteCommandID is written synchronously on serverQueue before
///     any async dispatch, guaranteeing the fallback is persisted even if the
///     main queue is delayed during the background wakeup.
///   - DispatchQueue.main.async (not Task { @MainActor in }) is used to call
///     ActionExecutionService.executeBackground(), which uses callback-based
///     UIApplication.open() — immune to Swift concurrency scheduler throttling.
///   - AppDelegate observes didBecomeActiveNotification as a guaranteed fallback
///     for the rare case where the main queue dispatch doesn't fire in time.
///   - Ownership check on pendingRemoteCommandID ensures exactly one path fires.
final class LocalActionServer {
    static let shared = LocalActionServer()

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
        let portNumber = UInt16(clamping: SharedStorage.shared.serverPort)
        let port = NWEndpoint.Port(rawValue: portNumber) ?? 8080
        guard let listener = try? NWListener(using: .tcp, on: port) else { return }
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.listener = nil
            default: break
            }
        }
        listener.start(queue: serverQueue)
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Per-connection background task

    private final class TaskBox {
        var id: UIBackgroundTaskIdentifier = .invalid
        func end() {
            let t = id; guard t != .invalid else { return }
            id = .invalid
            UIApplication.shared.endBackgroundTask(t)
        }
    }

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        let task = TaskBox()
        task.id = UIApplication.shared.beginBackgroundTask(withName: "RemoteCommand") {
            connection.cancel()
            task.end()
        }
        connection.start(queue: serverQueue)
        let timeout = DispatchWorkItem { connection.cancel(); task.end() }
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
            send(status: 405, body: "Method Not Allowed", to: connection); task.end(); return
        }
        guard let url = URL(string: "http://localhost\(parts[1])"),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.path == "/execute-widget-action" else {
            send(status: 404, body: "Not Found", to: connection); task.end(); return
        }
        guard let commandID = comps.queryItems?.first(where: { $0.name == "id" })?.value else {
            send(status: 400, body: "Missing id parameter", to: connection); task.end(); return
        }
        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else {
            send(status: 404, body: "Command not found: \(commandID)", to: connection); task.end(); return
        }

        // Write the pending slot SYNCHRONOUSLY on serverQueue — before any async
        // dispatch. This guarantees the fallback is persisted even if DispatchQueue.main
        // is delayed or throttled during the background wakeup.
        SharedStorage.shared.pendingRemoteCommandID = commandID

        send(status: 200, body: "OK: \(entry.label)", to: connection)

        let capturedCommandID = commandID
        let capturedEntry = entry
        DispatchQueue.main.async {
            // Claim the pending slot. If drain already ran (app became active first),
            // skip to avoid double-fire.
            guard SharedStorage.shared.pendingRemoteCommandID == capturedCommandID else {
                task.end(); return
            }
            SharedStorage.shared.pendingRemoteCommandID = nil
            // Use callback-based open — no Swift concurrency scheduler, executes
            // immediately on main thread during voip wakeup without throttling.
            ActionExecutionService.shared.executeBackground(capturedEntry.action) {
                task.end()
            }
        }
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
        connection.send(content: Data(response.utf8),
                        completion: .contentProcessed { _ in connection.cancel() })
    }
}

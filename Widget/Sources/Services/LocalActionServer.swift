import Foundation
import Network
import UIKit

/// Local HTTP TCP server that listens for widget action commands on the LAN.
/// Starts automatically when Wi-Fi is connected and an SSID is configured.
/// Uses NWPathMonitor (no special entitlement) instead of NEHotspotNetwork.
final class LocalActionServer {
    static let shared = LocalActionServer()

    private var listener: NWListener?
    private var pathMonitor: NWPathMonitor?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    var isRunning: Bool { listener != nil }

    // MARK: - Public API

    /// Start the server. No-op if no SSID is configured.
    func start() {
        guard !SharedStorage.shared.allowedSSID.isEmpty else {
            stop()
            return
        }
        startPathMonitor()
    }

    /// Stop the server and path monitor entirely.
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
        monitor.start(queue: .global(qos: .utility))
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
            case .failed, .cancelled:
                self?.listener = nil
                self?.endBackgroundTask()
            default: break
            }
        }
        renewBackgroundTask()
        listener.start(queue: .global(qos: .utility))
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
        endBackgroundTask()
    }

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            defer { connection.cancel() }
            guard let data, let request = String(data: data, encoding: .utf8) else {
                self?.send(status: 400, body: "Bad Request", to: connection)
                return
            }
            self?.process(request: request, connection: connection)
        }
    }

    private func process(request: String, connection: NWConnection) {
        let firstLine = request.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            send(status: 405, body: "Method Not Allowed", to: connection)
            return
        }

        guard let url = URL(string: "http://localhost\(parts[1])"),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.path == "/execute-widget-action" else {
            send(status: 404, body: "Not Found", to: connection)
            return
        }

        guard let commandID = comps.queryItems?.first(where: { $0.name == "id" })?.value else {
            send(status: 400, body: "Missing id parameter", to: connection)
            return
        }

        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else {
            send(status: 404, body: "Command not found: \(commandID)", to: connection)
            return
        }

        Task { @MainActor in
            try? await ActionExecutionService.shared.execute(action: entry.action)
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
        connection.send(content: Data(response.utf8),
                        completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: - Background task

    private func renewBackgroundTask() {
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "LocalActionServer") { [weak self] in
            self?.renewBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

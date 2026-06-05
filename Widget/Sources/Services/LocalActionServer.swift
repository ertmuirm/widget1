import Foundation
import Network
import NetworkExtension
import UIKit

/// Local HTTP TCP server that listens for widget action commands on the LAN.
/// Only starts when a specific Wi-Fi SSID is configured AND the device is currently
/// connected to that network. If no SSID is configured the server stays fully off
/// so it consumes no background battery.
final class LocalActionServer {
    static let shared = LocalActionServer()

    private var listener: NWListener?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    var isRunning: Bool { listener != nil }

    // MARK: - Public API

    func start() {
        let ssid = SharedStorage.shared.allowedSSID
        // If no SSID is configured the server is intentionally disabled.
        guard !ssid.isEmpty else { return }

        NEHotspotNetwork.fetchCurrent { [weak self] network in
            guard let self else { return }
            // Only start if we are actually on the configured network.
            // nil means Wi-Fi is not connected — do not run.
            guard let currentSSID = network?.ssid, currentSSID == ssid else { return }
            DispatchQueue.main.async { self.startListener() }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        endBackgroundTask()
    }

    // MARK: - Listener lifecycle

    private func startListener() {
        stop()
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
            default:
                break
            }
        }

        renewBackgroundTask()
        listener.start(queue: .global(qos: .utility))
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
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.path == "/execute-widget-action" else {
            send(status: 404, body: "Not Found", to: connection)
            return
        }

        guard let commandID = components.queryItems?.first(where: { $0.name == "id" })?.value else {
            send(status: 400, body: "Missing id parameter", to: connection)
            return
        }

        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else {
            send(status: 404, body: "Command not found: \(commandID)", to: connection)
            return
        }

        DispatchQueue.main.async {
            ActionExecutionService.shared.execute(action: entry.action)
        }
        send(status: 200, body: "OK: \(entry.label)", to: connection)
    }

    private func send(status: Int, body: String, to connection: NWConnection) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        default:  statusText = "Error"
        }
        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Length: \(body.utf8.count)\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n\(body)"
        let data = Data(response.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
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

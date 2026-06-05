import Foundation
import Network
import UIKit

/// Local HTTP TCP server that listens for widget action commands on the LAN.
///
/// Background/locked-screen lifecycle:
///   - UIBackgroundModes: voip (Info.plist) keeps the listening socket alive at
///     the kernel level. The app process is fully suspended between connections;
///     the kernel wakes it only when a TCP packet arrives.
///   - A single (non-renewing) background task covers the brief wakeup-to-receive
///     window. On expiration it ends cleanly so the app can re-suspend.
///   - NWPathMonitor tears down the listener the moment Wi-Fi disconnects.
final class LocalActionServer {
    static let shared = LocalActionServer()

    /// Serial queue at .background QoS. Signals the CPU scheduler to stay at
    /// a low-power frequency while idle between packets.
    private let serverQueue = DispatchQueue(label: "com.app.serverQueue", qos: .background)

    private var listener: NWListener?
    private var pathMonitor: NWPathMonitor?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    var isRunning: Bool { listener != nil }

    // MARK: - Public API

    func start() {
        guard !SharedStorage.shared.allowedSSID.isEmpty else {
            stop()
            return
        }
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
        // allowedSSID and serverPort are in UserDefaults.standard — plain plist,
        // always readable regardless of device lock state; no Keychain decryption.
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
        beginBackgroundTask()
        listener.start(queue: serverQueue)
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
        endBackgroundTask()
    }

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        connection.start(queue: serverQueue)

        // 5-second receive timeout: cancel idle connections immediately so the
        // app is not kept awake by a client that connects but never sends data.
        let timeout = DispatchWorkItem { connection.cancel() }
        serverQueue.asyncAfter(deadline: .now() + 5, execute: timeout)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            timeout.cancel()
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

        // pushCommandEntries are stored with kSecAttrAccessibleAfterFirstUnlock —
        // readable after first device unlock regardless of screen-lock state.
        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else {
            send(status: 404, body: "Command not found: \(commandID)", to: connection)
            return
        }

        // Dispatch the action immediately, then flush response and release socket.
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
        // Cancel the connection the instant the last byte is acknowledged.
        connection.send(content: Data(response.utf8),
                        completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: - Background task

    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        // Acquired once when the listener starts. With UIBackgroundModes: voip
        // this token only needs to cover the wakeup-to-first-receive window.
        // On expiration we end it cleanly and let the app fully re-suspend;
        // the voip socket remains alive and the next packet will wake the app again.
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "LocalActionServer") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

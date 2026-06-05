import Foundation
import Network
import UIKit

/// Local HTTP TCP server that listens for widget action commands on the LAN.
///
/// Background/locked-screen operation:
///   - UIBackgroundModes: voip (Info.plist) keeps the listening socket alive
///     indefinitely — iOS wakes the app when a packet arrives rather than
///     suspending the socket after the background-task time limit expires.
///   - beginBackgroundTask acts as a secondary safety net for non-socket wakeups.
///   - NWPathMonitor kills the listener the moment Wi-Fi disconnects.
///   - A 30-second timer kills the listener if the saved SSID is cleared while
///     the app is backgrounded (covers "user disabled server" scenario).
final class LocalActionServer {
    static let shared = LocalActionServer()

    /// Dedicated background-QoS serial queue. Keeping the server on a .background
    /// queue signals the CPU scheduler to stay at a low-power frequency while
    /// idle between packets.
    private let serverQueue = DispatchQueue(label: "com.app.serverQueue", qos: .background)

    private var listener: NWListener?
    private var pathMonitor: NWPathMonitor?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var validationTimer: Timer?

    private init() {}

    var isRunning: Bool { listener != nil }

    // MARK: - Public API

    /// Start the server. No-op (and stops any running instance) if no SSID is configured.
    func start() {
        guard !SharedStorage.shared.allowedSSID.isEmpty else {
            stop()
            return
        }
        startPathMonitor()
        scheduleValidationTimer()
    }

    /// Stop the server, path monitor, and validation timer entirely.
    func stop() {
        validationTimer?.invalidate()
        validationTimer = nil
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

    // MARK: - Kill-switch validation timer

    /// Fires every 30 seconds to check that the saved SSID hasn't been cleared
    /// while the server is running in the background.
    ///
    /// Note: NEHotspotNetwork.fetchCurrent (actual SSID comparison) requires
    /// com.apple.developer.networking.wifi-info which is unavailable on sideloaded
    /// apps. NWPathMonitor handles Wi-Fi on/off transitions; this timer covers the
    /// softer "user deleted their SSID config" case.
    private func scheduleValidationTimer() {
        validationTimer?.invalidate()
        // Timer must be scheduled on the main run loop.
        validationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            if SharedStorage.shared.allowedSSID.isEmpty {
                self.stop()
            }
        }
    }

    // MARK: - Listener lifecycle

    private func startListener() {
        // allowedSSID and serverPort live in UserDefaults.standard which is stored
        // as a plain plist file — always readable regardless of device lock state.
        // No Keychain decryption occurs here, so no encryption spike when the
        // screen is black.
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
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            // No defer cancel here. send() cancels the connection inside its
            // contentProcessed completion after the last byte is flushed.
            // A premature cancel would race with the async send and abort
            // the HTTP response mid-flight.
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

        // pushCommandEntries are stored via scatterWrite which writes to Keychain
        // with kSecAttrAccessibleAfterFirstUnlock — readable after first device
        // unlock regardless of subsequent screen-lock state.
        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else {
            send(status: 404, body: "Command not found: \(commandID)", to: connection)
            return
        }

        // Dispatch the action the instant the matching command is found, then
        // immediately queue the response + socket teardown. The socket is fully
        // released inside send()'s contentProcessed callback — no lingering state.
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
        // Cancel the connection the instant the last byte is acknowledged —
        // zero lingering socket threads.
        connection.send(content: Data(response.utf8),
                        completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: - Background task

    private func renewBackgroundTask() {
        endBackgroundTask()
        // With UIBackgroundModes: voip the OS keeps the socket alive without
        // consuming background task time. beginBackgroundTask here is a safety
        // net that ensures the app gets a chance to finish any in-flight work
        // even if the voip socket wakeup hasn't fired yet.
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

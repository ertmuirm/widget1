import Foundation
import Network
import NetworkExtension
import UIKit

final class LocalActionServer {

    static let shared = LocalActionServer()
    private init() {}

    private var listener: NWListener?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private let queue = DispatchQueue(label: "com.ioswidget.localserver", qos: .utility)

    var isRunning: Bool { listener != nil }

    // MARK: - Lifecycle

    func start() {
        stop()
        let portNum = UInt16(clamping: SharedStorage.shared.serverPort)
        let port = NWEndpoint.Port(rawValue: portNum) ?? 8080
        guard let l = try? NWListener(using: .tcp, on: port) else { return }
        listener = l
        l.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.listener = nil }
            if case .cancelled = state { self?.listener = nil }
        }
        l.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        l.start(queue: queue)
        refreshBackgroundTask()
    }

    func stop() {
        listener?.cancel()
        listener = nil
        endBackgroundTask()
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - Background Task

    private func refreshBackgroundTask() {
        endBackgroundTask()
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "LocalActionServer") { [weak self] in
            // Re-request on expiry to maximise uptime while app is backgrounded
            self?.refreshBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }

    // MARK: - Connection Handling

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        let saved = SharedStorage.shared.allowedSSID
        guard !saved.isEmpty else {
            receiveRequest(on: connection)
            return
        }
        // SSID guard: compare current SSID to the saved one.
        // If SSID cannot be read (entitlement missing → nil), allow the connection.
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            guard let self = self else { return }
            if network == nil || network?.ssid == saved {
                self.receiveRequest(on: connection)
            } else {
                self.sendResponse(on: connection, status: 403, body: "Forbidden")
            }
        }
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            let raw = String(decoding: data, as: UTF8.self)
            let firstLine = raw.components(separatedBy: "\r\n").first ?? ""
            let parts = firstLine.components(separatedBy: " ")
            guard parts.count >= 2 else {
                self.sendResponse(on: connection, status: 400, body: "Bad Request")
                return
            }
            self.dispatch(path: parts[1], on: connection)
        }
    }

    private func dispatch(path: String, on connection: NWConnection) {
        guard
            let url = URL(string: "http://localhost" + path),
            url.path == "/execute-widget-action",
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            let id = items.first(where: { $0.name == "id" })?.value,
            !id.isEmpty
        else {
            sendResponse(on: connection, status: 404, body: "Not Found")
            return
        }

        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let match = entries.first(where: { $0.command == id }) else {
            sendResponse(on: connection, status: 404, body: "Command not found: \(id)")
            return
        }

        let action = match.action
        DispatchQueue.main.async {
            Task { _ = try? await ActionExecutionService.shared.execute(action: action) }
        }
        sendResponse(on: connection, status: 200, body: "OK")
    }

    private func sendResponse(on connection: NWConnection, status: Int, body: String) {
        let bodyData = body.data(using: .utf8) ?? Data()
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 403: statusText = "Forbidden"
        case 404: statusText = "Not Found"
        default:  statusText = "Error"
        }
        let header = "HTTP/1.1 \(status) \(statusText)\r\nContent-Length: \(bodyData.count)\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n"
        var response = header.data(using: .utf8)!
        response.append(bodyData)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Tell iOS to call performFetchWithCompletionHandler as often as possible.
        // iOS still decides the exact schedule; "minimum" is just a lower bound.
        UIApplication.shared.setMinimumBackgroundFetchInterval(
            UIApplication.backgroundFetchIntervalMinimum
        )
        return true
    }

    // MARK: - Background Fetch — ntfy.sh HTTP Polling
    //
    // iOS calls this when it grants background CPU time (UIBackgroundModes: fetch).
    // No push certificate or paid developer account required.
    //
    // Protocol:
    //   GET https://ntfy.sh/{topic}/json?poll=1&since={lastMessageId}
    //   Response: newline-delimited JSON, one message object per line.
    //
    // BATTERY: completionHandler fires immediately after dispatching matched
    // actions so the OS can reclaim the CPU as quickly as possible.

    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let topic = SharedStorage.shared.ntfyTopic

        // "since" is either the last seen message ID (string) or, on first run,
        // the current Unix timestamp so we skip messages sent before monitoring started.
        let since = SharedStorage.shared.ntfyLastMessageID
            ?? String(Int(Date().timeIntervalSince1970))

        guard let url = URL(string: "https://ntfy.sh/\(topic)/json?poll=1&since=\(since)") else {
            completionHandler(.noData)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            SharedStorage.shared.ntfyLastPollDate = Date()

            guard let data = data, error == nil, !data.isEmpty else {
                completionHandler(error == nil ? .noData : .failed)
                return
            }

            let lines = String(decoding: data, as: UTF8.self)
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }

            let entries = SharedStorage.shared.loadPushCommandEntries()
            var lastID: String?
            var executedAny = false

            for line in lines {
                guard
                    let lineData = line.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                    json["event"] as? String == "message",
                    let msgID   = json["id"] as? String,
                    let message = json["message"] as? String
                else { continue }

                lastID = msgID

                let command = message.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let match = entries.first(where: { $0.command == command }) else { continue }

                let action = match.action
                DispatchQueue.main.async {
                    Task { _ = try? await ActionExecutionService.shared.execute(action: action) }
                }
                executedAny = true
            }

            if let id = lastID {
                SharedStorage.shared.ntfyLastMessageID = id
            }

            // Signal OS immediately — do NOT wait for async action execution
            completionHandler(executedAny ? .newData : .noData)
        }.resume()
    }
}

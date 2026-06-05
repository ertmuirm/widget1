import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestPushAuthorization(application: application)
        return true
    }

    // MARK: - Push Registration

    private func requestPushAuthorization(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        SharedStorage.shared.ntfyDeviceToken = tokenHex
        SharedStorage.shared.ntfyRegistrationStatus = "Registering…"
        registerTokenWithNtfy(tokenHex)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        SharedStorage.shared.ntfyRegistrationStatus = "APNS error: \(error.localizedDescription)"
    }

    // MARK: - ntfy.sh Token Registration
    //
    // Binds our APNS device token to our unique topic on ntfy.sh.
    // After registration, any POST to https://ntfy.sh/<topic> is forwarded
    // to this device as an APNS silent push.

    private func registerTokenWithNtfy(_ tokenHex: String) {
        let topic = SharedStorage.shared.ntfyTopic

        guard let url = URL(string: "https://ntfy.sh/v1/account/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "token": tokenHex,
            "subscriptions": [["topic": topic]]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                SharedStorage.shared.ntfyRegistrationStatus = "Registered"
            } else {
                let detail = error?.localizedDescription
                    ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                SharedStorage.shared.ntfyRegistrationStatus = "Error: \(detail)"
            }
        }.resume()
    }

    // MARK: - Silent Background Push Handler
    //
    // Called when a silent push (content-available: 1) arrives from ntfy.sh.
    // ntfy.sh places the published message text in the "ntfy_message" key.
    //
    // BATTERY: completionHandler fires immediately after dispatching the
    // action so the OS can suspend the CPU back to sleep within milliseconds.
    // The action itself runs fire-and-forget on the main actor.

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let rawMessage = userInfo["ntfy_message"] as? String else {
            completionHandler(.noData)
            return
        }

        let command = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let entries = SharedStorage.shared.loadPushCommandEntries()

        guard let match = entries.first(where: { $0.command == command }) else {
            completionHandler(.noData)
            return
        }

        // Signal OS immediately — do NOT await the action
        completionHandler(.newData)

        // Execute the mapped action on the main actor, fire-and-forget
        let action = match.action
        DispatchQueue.main.async {
            Task { _ = try? await ActionExecutionService.shared.execute(action: action) }
        }
    }

    // MARK: - Foreground Notification Display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Suppress banners for ntfy command pushes; they are silent by design
        completionHandler([])
    }
}

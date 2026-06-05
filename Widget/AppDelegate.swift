import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        LocalActionServer.shared.start()
        // Suppress notification banners when the app is already in foreground
        // (drain handles execution immediately in that case).
        UNUserNotificationCenter.current().delegate = self
        // Request permission on first launch; needed for command-arrival notifications.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        // UIApplicationDelegate.applicationDidBecomeActive is intercepted by SwiftUI's
        // scene lifecycle and does not fire reliably. NotificationCenter fires in all cases.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppDelegate.drainPendingRemoteCommand()
        }
        return true
    }

    /// Execute any command that arrived while the app was backgrounded.
    /// Static so it can be called from the NotificationCenter closure without
    /// capturing self (AppDelegate lifetime is tied to the process).
    static func drainPendingRemoteCommand() {
        guard let commandID = SharedStorage.shared.pendingRemoteCommandID else { return }
        SharedStorage.shared.pendingRemoteCommandID = nil
        // Cancel the notification that triggered this drain (if still pending/delivered).
        let notifID = "cmd-\(commandID)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notifID])
        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else { return }
        Task { @MainActor in
            try? await ActionExecutionService.shared.execute(action: entry.action)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Suppress notification banners while the app is in the foreground — drain
    /// handles execution immediately so the banner would be noise.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return []
    }
}

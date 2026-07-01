import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        LocalActionServer.shared.start()
        // UIApplicationDelegate.applicationDidBecomeActive is intercepted by SwiftUI's
        // scene lifecycle and does not fire reliably. NotificationCenter fires in all cases.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppDelegate.drainPendingRemoteCommand()
        }

        // Request notification permissions for toast notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        return true
    }

    /// Execute any command that arrived while the app was backgrounded.
    /// Static so it can be called from the NotificationCenter closure without
    /// capturing self (AppDelegate lifetime is tied to the process).
    static func drainPendingRemoteCommand() {
        guard let commandID = SharedStorage.shared.pendingRemoteCommandID else { return }
        SharedStorage.shared.pendingRemoteCommandID = nil
        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else { return }
        ActionExecutionService.shared.executeBackground(entry.action) { }
    }
}

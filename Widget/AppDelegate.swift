import UIKit
import WidgetKit

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
            AppDelegate.drainPendingWidgetAction()
        }
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

    /// Process pending widget action from Button(intent:) taps and refresh widget.
    static func drainPendingWidgetAction() {
        let pendingKey = "pendingWidgetAction"
        guard let encodedAction = UserDefaults.standard.string(forKey: pendingKey) else { return }
        
        // Clear the pending action
        UserDefaults.standard.removeObject(forKey: pendingKey)
        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.removeObject(forKey: pendingKey)
        }
        
        // Decode and execute the action
        guard let data = Data(base64Encoded: encodedAction),
              let action = try? JSONDecoder().decode(WidgetAction.self, from: data) else { return }
        
        switch action.type {
        case .urlScheme:
            if let url = URL(string: action.payload) {
                UIApplication.shared.open(url)
            }
        case .shortcut:
            if let encoded = action.payload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)") {
                UIApplication.shared.open(url)
            }
        case .appIntent:
            // For appIntent, the payload is the bundle ID - just try to open via URL scheme
            if let encoded = action.payload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "openapp://launch?bundle=\(encoded)") {
                UIApplication.shared.open(url)
            }
        }
        
        // Refresh the widget
        WidgetCenter.shared.reloadAllTimelines()
    }
}

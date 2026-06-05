import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        LocalActionServer.shared.start()
        return true
    }

    /// Execute any command that arrived while the app was backgrounded.
    func applicationDidBecomeActive(_ application: UIApplication) {
        drainPendingRemoteCommand()
    }

    /// Called when iOS routes openapp:// back into this app (triggered by LocalActionServer
    /// to bring the app to foreground after a background command is received).
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard url.scheme == "openapp" else { return false }
        drainPendingRemoteCommand()
        return true
    }

    private func drainPendingRemoteCommand() {
        guard let commandID = SharedStorage.shared.pendingRemoteCommandID else { return }
        SharedStorage.shared.pendingRemoteCommandID = nil
        let entries = SharedStorage.shared.loadPushCommandEntries()
        guard let entry = entries.first(where: { $0.command == commandID }) else { return }
        Task { @MainActor in
            try? await ActionExecutionService.shared.execute(action: entry.action)
        }
    }
}

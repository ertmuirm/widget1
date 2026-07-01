import AppIntents
import UserNotifications

// MARK: - Toast Notification Intent

struct ToastNotificationIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger Custom Toast"
    static var description = IntentDescription("Trigger an Android-style toast notification in the background. Can be used with Shortcuts or automations.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "Message", description: "The text to display in the toast notification")
    var message: String

    init() {
        self.message = "Success!"
    }

    init(message: String) {
        self.message = message
    }

    func perform() async throws -> some IntentResult {
        let center = UNUserNotificationCenter.current()

        // Check notification settings
        let settings = try await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            // Silently return if not authorized - don't prompt user
            return .result()
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.body = message
        content.sound = UNNotificationSound(name: UNNotificationSoundName("ToastSound.wav"))

        // Trigger after 1 second for near-instant display
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create unique request
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        // Schedule the notification
        try await center.add(request)

        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct ToastShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToastNotificationIntent(),
            phrases: [
                "Show toast with \(.applicationName)",
                "Trigger toast notification with \(.applicationName)",
                "Display message with \(.applicationName)"
            ],
            shortTitle: "Trigger Custom Toast",
            systemImageName: "bell.badge"
        )
    }
}

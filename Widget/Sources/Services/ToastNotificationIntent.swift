import AppIntents
import UserNotifications

// MARK: - Toast Notification Intent

struct ToastNotificationIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger Custom Toast"
    static var description = IntentDescription("Displays an Android-style toast notification with custom text.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "Message",
               description: "The text to display in the toast notification.",
               default: "Success!")
    var message: String

    init() { message = "Success!" }
    init(message: String) { self.message = message }

    func perform() async throws -> some IntentResult {
        let center = UNUserNotificationCenter.current()

        // Check notification settings/authorization
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            return .result()
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.body = message
        content.sound = UNNotificationSound(named: UNNotificationSoundName("ToastSound.wav"))

        // Schedule notification with 1-second delay for instant delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // Silently fail - toast is non-critical
        }

        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct ToastShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToastNotificationIntent(),
            phrases: [
                "Show notification in \(.applicationName)",
                "Show toast in \(.applicationName)",
                "Trigger toast notification",
                "Display custom toast"
            ],
            shortTitle: "Show Notification",
            systemImageName: "bell.badge"
        )
    }
}
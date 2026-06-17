import WidgetKit

/// Handles Darwin notifications from the main app to trigger widget timeline refreshes.
///
/// On sideloaded apps (SideStore/AltStore), WidgetCenter.shared.reloadTimelines() may not
/// reliably work from the main app process. This handler listens for Darwin notifications
/// and forces the widget extension to reload its timelines immediately.
final class WidgetNotificationHandler {

    // MARK: - Singleton

    static let shared = WidgetNotificationHandler()

    // MARK: - Properties

    private var isObserving = false

    // MARK: - Init

    private init() {
        startObserving()
    }

    // MARK: - Observation

    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        // Observe swap action notification - reload all grid widget timelines
        DarwinNotificationCenter.shared.observeSwapAction { [weak self] in
            self?.reloadGridWidgets()
        }

        // Observe slide advance notification - reload image widget timeline
        DarwinNotificationCenter.shared.observeSlideAdvance { [weak self] in
            self?.reloadImageWidget()
        }

        // Observe generic widget update notification - reload all timelines
        DarwinNotificationCenter.shared.observeWidgetUpdate { [weak self] in
            self?.reloadAllWidgets()
        }
    }

    // MARK: - Reload Methods

    private func reloadGridWidgets() {
        // Reload all grid widget timelines (Small, Medium, Large)
        WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastSmall")
        WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastMedium")
        WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastLarge")
    }

    private func reloadImageWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastImage")
    }

    private func reloadClockWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastClock")
    }

    private func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Automatic Initialization

/// Accessing this property triggers the singleton's initialization,
/// which starts listening for Darwin notifications.
@propertyWrapper
struct DarwinNotificationObserver {
    static let handler = WidgetNotificationHandler.shared
    var wrappedValue: Bool { true }
}

/// This file-scoped constant ensures the notification handler is initialized
/// when the widget extension loads, without requiring any explicit calls.
private let _notificationHandler = WidgetNotificationHandler.shared

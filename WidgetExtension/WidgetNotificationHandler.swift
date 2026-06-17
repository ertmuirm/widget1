import WidgetKit

/// Handles Darwin notifications from the main app to trigger widget timeline refreshes.
/// 
/// This is best-effort - the extension may be suspended and won't receive notifications.
/// The widget will still refresh when touched since makeEntry() always reads fresh data.
final class WidgetNotificationHandler {

    static let shared = WidgetNotificationHandler()

    private init() {
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

    private func reloadGridWidgets() {
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

/// This file-scoped constant ensures the notification handler is initialized
/// when the widget extension loads.
private let _notificationHandler = WidgetNotificationHandler.shared

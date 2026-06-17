import Foundation

/// Darwin notification-based inter-process communication for widget updates.
///
/// On sideloaded apps (SideStore/AltStore), WidgetCenter.shared.reloadTimelines() may not
/// reliably wake the widget extension process. This helper uses low-level Darwin notify
/// API to post/listen for cross-process notifications, ensuring widget updates work reliably.
///
/// Darwin notifications are kernel-level IPC - they're the most reliable way to communicate
/// between processes on iOS, especially for sideloaded apps.
final class DarwinNotificationCenter {

    // MARK: - Constants

    /// Posted when widget data changes and timelines should be reloaded.
    /// Listened to by the widget extension to trigger immediate refresh.
    static let widgetUpdateNotification = "com.ioswidget.widgetUpdate" as CFString

    /// Posted when a swap action is performed.
    static let swapActionNotification = "com.ioswidget.swapAction" as CFString

    /// Posted when a slide advance action is performed.
    static let slideAdvanceNotification = "com.ioswidget.slideAdvance" as CFString

    // MARK: - Singleton

    static let shared = DarwinNotificationCenter()

    private init() {}

    // MARK: - Post Notification (Sender side)

    /// Posts the widget update Darwin notification to wake up the widget extension.
    /// Call this after saving any widget data that should trigger a refresh.
    func postWidgetUpdate() {
        postDarwinNotification(name: Self.widgetUpdateNotification)
    }

    /// Posts a swap action Darwin notification.
    func postSwapAction() {
        postDarwinNotification(name: Self.swapActionNotification)
    }

    /// Posts a slide advance Darwin notification.
    func postSlideAdvance() {
        postDarwinNotification(name: Self.slideAdvanceNotification)
    }

    /// Generic Darwin notification poster.
    /// - Parameter name: The notification name (CFString)
    private func postDarwinNotification(name: CFString) {
        // Use Darwin NotifyCenter for cross-process notifications
        // The `true` parameter means "post to Darwin Notify Center for current task"
        // This will wake any process listening for this notification
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name),
            nil,
            nil,
            true
        )
    }

    // MARK: - Observe Notification (Receiver side)

    /// Callback type for notification observations
    typealias NotificationCallback = () -> Void

    /// Observers storage: notification name -> callback
    private var observers: [CFString: NotificationCallback] = [:]

    /// Starts observing the widget update notification.
    /// The callback will be invoked on the main thread when the notification is posted.
    /// - Parameter callback: Closure to execute when notification is received
    func observeWidgetUpdate(callback: @escaping NotificationCallback) {
        addObserver(for: Self.widgetUpdateNotification, callback: callback)
    }

    /// Starts observing the swap action notification.
    func observeSwapAction(callback: @escaping NotificationCallback) {
        addObserver(for: Self.swapActionNotification, callback: callback)
    }

    /// Starts observing the slide advance notification.
    func observeSlideAdvance(callback: @escaping NotificationCallback) {
        addObserver(for: Self.slideAdvanceNotification, callback: callback)
    }

    /// Generic Darwin notification observer.
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - callback: Closure to execute when notification is received
    private func addObserver(for name: CFString, callback: @escaping NotificationCallback) {
        // Store the callback so it can be invoked from C callback
        observers[name] = callback

        // Create a C-compatible callback that invokes the Swift closure
        // Note: We need to use a static/global callback because Darwin notifications
        // use a C callback pattern that doesn't support Swift closures directly
        let observerBlock: CFNotificationCallback = { _, observer, name, _, _ in
            guard let observer = observer, let name = name else { return }
            let center = Unmanaged<DarwinNotificationCenter>.fromOpaque(observer).takeUnretainedValue()
            if let callback = center.observers[name.rawValue as CFString] {
                DispatchQueue.main.async {
                    callback()
                }
            }
        }

        // Retain self for the callback
        let retainedSelf = Unmanaged.passRetained(self)

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            retainedSelf.toOpaque(),
            observerBlock,
            name,
            nil,
            .deliverImmediately
        )
    }

    /// Stops all observation for a specific notification.
    func removeObserver(for name: CFString) {
        observers.removeValue(forKey: name)
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passRetained(self).toOpaque(),
            CFNotificationName(name),
            nil
        )
    }

    /// Stops all observations.
    func removeAllObservers() {
        for name in observers.keys {
            removeObserver(for: name)
        }
    }

    deinit {
        removeAllObservers()
    }
}

import UIKit

// MARK: - Foreground-to-foreground opens (LauncherGridView)
//
// These variants call suspend after opening so iOS transitions cleanly
// without a foreground→background animation.  Only safe to call when
// the app is already in the foreground (user is actively using it).

/// Opens a URL via LSApplicationWorkspace, then immediately suspends.
func openURLFast(_ url: URL) {
    openURLViaWorkspace(url)
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
}

/// Opens an app by bundle ID via LSApplicationWorkspace, then immediately suspends.
func openAppFast(bundleID: String) {
    openAppViaWorkspace(bundleID: bundleID)
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
}

// MARK: - Background-launched opens (onOpenURL / widget taps)
//
// These variants do NOT call suspend.  When a widget is tapped the app may be
// launching from a terminated or suspended state; calling suspend immediately
// after launch confuses iOS and causes a 5-10s deferral before the URL opens.

/// Opens a URL via LSApplicationWorkspace without suspending afterward.
func openURLDirect(_ url: URL) {
    openURLViaWorkspace(url)
}

/// Opens an app by bundle ID via LSApplicationWorkspace without suspending.
/// Falls back to the fallback URL if LSApplicationWorkspace is unavailable.
func openAppDirect(bundleID: String, fallbackURL: URL? = nil) {
    let sel = NSSelectorFromString("openApplicationWithBundleID:")
    if let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
       let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
       ws.responds(to: sel) {
        ws.perform(sel, with: bundleID)
    } else if let url = fallbackURL {
        openURLViaWorkspace(url)
    }
}

// MARK: - Shared workspace helper

private func openURLViaWorkspace(_ url: URL) {
    let sel = NSSelectorFromString("openURL:")
    if let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
       let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
       ws.responds(to: sel) {
        ws.perform(sel, with: url)
    } else {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

private func openAppViaWorkspace(bundleID: String) {
    let sel = NSSelectorFromString("openApplicationWithBundleID:")
    if let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
       let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
       ws.responds(to: sel) {
        ws.perform(sel, with: bundleID)
    }
}

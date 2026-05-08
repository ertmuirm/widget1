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

// MARK: - Widget-tap opens (onOpenURL — app state unknown)
//
// LSApplicationWorkspace.openURL: is synchronous: SpringBoard receives the
// request before the call returns.  We then suspend after 50ms so UIKit's
// slow foreground→background animation never plays, but the launch transition
// has had a moment to settle (immediate suspend during launch caused a 5-10s
// deferral in earlier attempts).

/// Opens a URL via LSApplicationWorkspace, then suspends after 50 ms.
func openURLDirect(_ url: URL) {
    openURLViaWorkspace(url)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        UIApplication.shared.perform(NSSelectorFromString("suspend"))
    }
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

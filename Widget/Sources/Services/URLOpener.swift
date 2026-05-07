import UIKit

/// Opens a URL via LSApplicationWorkspace, then immediately suspends.
///
/// UIApplication.open(_:options:completionHandler:) is async even with a nil handler —
/// iOS still runs the full foreground→background transition animation (~5s) before the
/// target app appears.  LSApplicationWorkspace.openURL: talks directly to SpringBoard
/// and is synchronous, so the switch is instant.  Calling suspend after it backgrounds
/// our app cleanly without a visible animation.
func openURLFast(_ url: URL) {
    let openSel = NSSelectorFromString("openURL:")
    if let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
       let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
       ws.responds(to: openSel) {
        ws.perform(openSel, with: url)
    } else {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
}

/// Opens an app by bundle ID via LSApplicationWorkspace, then immediately suspends.
func openAppFast(bundleID: String) {
    let openSel = NSSelectorFromString("openApplicationWithBundleID:")
    if let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
       let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
       ws.responds(to: openSel) {
        ws.perform(openSel, with: bundleID)
    }
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
}

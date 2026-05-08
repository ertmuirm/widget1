import UIKit

// MARK: - Foreground opens (LauncherGridView only)
//
// These functions are called when the app is definitely in the foreground
// (the user is interacting with the launcher grid).  LSApplicationWorkspace
// is synchronous — SpringBoard receives the request before the call returns —
// then suspend immediately backgrounds our app so no slow UIKit animation plays.
// Do NOT use these from onOpenURL; widget taps use the original async UIApplication
// path in WidgetApp which handled them correctly before the launcher grid was added.

/// Opens a URL via LSApplicationWorkspace then immediately suspends.
func openURLFast(_ url: URL) {
    let sel = NSSelectorFromString("openURL:")
    if let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
       let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
       ws.responds(to: sel) {
        ws.perform(sel, with: url)
    } else {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
}

/// Opens an app by bundle ID via LSApplicationWorkspace then immediately suspends.
func openAppFast(bundleID: String) {
    let sel = NSSelectorFromString("openApplicationWithBundleID:")
    if let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
       let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
       ws.responds(to: sel) {
        ws.perform(sel, with: bundleID)
    }
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
}

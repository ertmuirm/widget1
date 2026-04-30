import SwiftUI

@main
struct WidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.scheme == "openapp" {
                        // Bundle-ID launch: openapp://launch?bundle=com.example.app
                        if let bundleID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == "bundle" })?.value {
                            openAppByBundleID(bundleID)
                        }
                    } else {
                        UIApplication.shared.open(url)
                    }
                }
        }
    }
}

/// Opens any installed app by bundle ID via LSApplicationWorkspace (private API,
/// accessible on SideStore-distributed builds — not App Store eligible).
/// Fails silently if the API is unavailable or the app is not installed.
private func openAppByBundleID(_ bundleID: String) {
    guard
        let cls = NSClassFromString("LSApplicationWorkspace"),
        let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue()
    else { return }
    _ = (ws as AnyObject).perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleID)
}

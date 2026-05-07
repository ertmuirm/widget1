import SwiftUI

@main
struct WidgetApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // onOpenURL fires on the main thread — no Task wrapper needed.
                    if url.scheme == "widgetar" {
                        // Handled by ContentView's .onOpenURL
                    } else if url.scheme == "openapp" {
                        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        if let bundleID = comps?.queryItems?.first(where: { $0.name == "bundle" })?.value {
                            let fallback = comps?.queryItems?.first(where: { $0.name == "fallback" })?.value
                            openAppByBundleID(bundleID, fallbackURLString: fallback)
                        }
                    } else {
                        openURLFast(url)
                    }
                }
                .onAppear {
                    InstalledAppsManager.shared.scan()
                }
        }
    }
}

// MARK: - Bundle-ID app launch via LSApplicationWorkspace (private API)

private func openAppByBundleID(_ bundleID: String, fallbackURLString: String? = nil) {
    let openSel = NSSelectorFromString("openApplicationWithBundleID:")
    if let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
       let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject,
       ws.responds(to: openSel) {
        ws.perform(openSel, with: bundleID)
        UIApplication.shared.perform(NSSelectorFromString("suspend"))
    } else if let str = fallbackURLString, let url = URL(string: str) {
        openURLFast(url)
    }
}

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
                    } else if url.scheme == "tel" {
                        dialPhoneNumber(url: url)
                    } else {
                        openURLImmediately(url)
                    }
                }
                .onAppear {
                    InstalledAppsManager.shared.scan()
                }
        }
    }
}

// MARK: - Phone dialling

private func dialPhoneNumber(url: URL) {
    UIApplication.shared.open(url)
}

// MARK: - Instant URL open

/// Opens a URL without the multi-second delay caused by awaiting UIApplication.open
/// from a foreground app.  The callback form (non-async, nil completion) is
/// fire-and-forget: it submits the open request immediately and returns.
/// iOS naturally backgrounds this app when the target app comes to the foreground.
private func openURLImmediately(_ url: URL) {
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
}

// MARK: - Bundle-ID app launch via LSApplicationWorkspace (private API)

private func openAppByBundleID(_ bundleID: String, fallbackURLString: String? = nil) {
    guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
          let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
    else {
        openFallbackURL(fallbackURLString)
        return
    }

    let openSel = NSSelectorFromString("openApplicationWithBundleID:")
    guard ws.responds(to: openSel) else {
        openFallbackURL(fallbackURLString)
        return
    }
    ws.perform(openSel, with: bundleID)
}

private func openFallbackURL(_ urlString: String?) {
    guard let str = urlString, let url = URL(string: str) else { return }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
}

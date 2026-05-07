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

// MARK: - Instant URL open (no foreground-open delay)

/// Backgrounds the app first so iOS handles the open without the
/// multi-second foreground→background resignation stall.
private func openURLImmediately(_ url: URL) {
    UIApplication.shared.perform(NSSelectorFromString("suspend"))
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
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
    openURLImmediately(url)
}

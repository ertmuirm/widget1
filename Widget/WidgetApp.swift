import SwiftUI

@main
struct WidgetApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task { @MainActor in
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
                            await UIApplication.shared.open(url)
                        }
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
    Task { await UIApplication.shared.open(url) }
}

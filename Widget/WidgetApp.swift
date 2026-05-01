import SwiftUI

@main
struct WidgetApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task { @MainActor in
                        // Brief yield so the black ContentView renders before handing off
                        try? await Task.sleep(for: .milliseconds(250))
                        if url.scheme == "openapp" {
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
    // Open tel: URL directly for a real cellular call.
    // CXStartCallAction routes through our VoIP provider which has no carrier backend,
    // so it would show the calling UI without actually connecting to the network.
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

    // Skip applicationIsInstalled: — its BOOL return value cannot be reliably cast
    // through NSInvocation's perform path, causing it to always appear false.
    // Just attempt openApplicationWithBundleID: directly; it silently fails if the
    // app is not installed, and the fallback URL covers that case where available.
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

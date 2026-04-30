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
    // Try URL scheme fallback first — most reliable on SideStore where private APIs may not work.
    if let str = fallbackURLString, let url = URL(string: str) {
        Task {
            if await UIApplication.shared.open(url) { return }
            // URL scheme failed; try LSApplicationWorkspace as last resort
            openViaWorkspace(bundleID)
        }
        return
    }
    openViaWorkspace(bundleID)
}

private func openViaWorkspace(_ bundleID: String) {
    guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
          let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
    else { return }
    let sel = NSSelectorFromString("openApplicationWithBundleID:")
    if ws.responds(to: sel) { ws.perform(sel, with: bundleID) }
}

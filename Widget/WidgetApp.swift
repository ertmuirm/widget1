import SwiftUI

@main
struct WidgetApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task { @MainActor in
                        // Brief yield so the black ContentView renders before handing off
                        try? await Task.sleep(for: .milliseconds(30))
                        if url.scheme == "openapp" {
                            if let bundleID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                                .queryItems?.first(where: { $0.name == "bundle" })?.value {
                                openAppByBundleID(bundleID)
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
    let raw = url.absoluteString
    let number = raw.hasPrefix("tel:") ? String(raw.dropFirst(4)) : raw

    CallKitManager.shared.dial(phoneNumber: number) { success in
        guard !success else { return }
        // CallKit rejected the request — fall back to tel: URL (shows system dialog)
        UIApplication.shared.open(url)
    }
}

// MARK: - Bundle-ID app launch via LSApplicationWorkspace (private API)

private func openAppByBundleID(_ bundleID: String) {
    guard
        let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
        let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
    else { return }
    ws.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleID)
}

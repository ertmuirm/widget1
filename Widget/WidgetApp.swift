import SwiftUI
import CallKit

@main
struct WidgetApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task { @MainActor in
                        // Brief yield so the black ContentView renders before we hand off
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

// MARK: - Phone dialling via CallKit (no confirmation dialog)

/// Attempts to start a phone call using CallKit, bypassing the system confirmation
/// dialog. Falls back to the tel: URL scheme (which shows a dialog) if CallKit fails.
private func dialPhoneNumber(url: URL) {
    // Strip "tel:" prefix to get the raw number
    let raw = url.absoluteString
    let number = raw.hasPrefix("tel:") ? String(raw.dropFirst(4)) : raw

    let handle = CXHandle(type: .phoneNumber, value: number)
    let action = CXStartCallAction(call: UUID(), handle: handle)
    action.isVideo = false
    let transaction = CXTransaction(action: action)

    CXCallController().request(transaction) { error in
        guard error != nil else { return }
        // CallKit not available or not authorised — fall back to tel: URL
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
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

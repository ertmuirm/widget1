import SwiftUI

@main
struct WidgetApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingBlackScreen = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showingBlackScreen {
                    Color.black.ignoresSafeArea()
                }
            }
            .onOpenURL { url in
                showingBlackScreen = true
                // Yield to let the black screen render before activating the target app
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(80))
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
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    showingBlackScreen = false
                }
            }
            .onAppear {
                InstalledAppsManager.shared.scan()
            }
        }
    }
}

/// Opens any installed app by bundle ID via LSApplicationWorkspace (private API,
/// accessible on SideStore-distributed builds — not App Store eligible).
/// Fails silently if the API is unavailable or the app is not installed.
private func openAppByBundleID(_ bundleID: String) {
    guard
        let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
        let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
    else { return }
    ws.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleID)
}

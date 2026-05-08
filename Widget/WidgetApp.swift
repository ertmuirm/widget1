import SwiftUI

@main
struct WidgetApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // onOpenURL fires on the main thread — no Task wrapper needed.
                    // Use the Direct variants (no suspend): the app may be launching
                    // from background/terminated state when a widget is tapped.
                    if url.scheme == "widgetar" {
                        // Handled by ContentView's .onOpenURL
                    } else if url.scheme == "openapp" {
                        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        if let bundleID = comps?.queryItems?.first(where: { $0.name == "bundle" })?.value {
                            let fallback = comps?.queryItems?.first(where: { $0.name == "fallback" })?.value
                                .flatMap { URL(string: $0) }
                            openAppDirect(bundleID: bundleID, fallbackURL: fallback)
                        }
                    } else {
                        openURLDirect(url)
                    }
                }
                .onAppear {
                    InstalledAppsManager.shared.scan()
                }
        }
    }
}

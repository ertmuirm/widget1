import SwiftUI

@main
struct WidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    UIApplication.shared.open(url)
                }
        }
    }
}

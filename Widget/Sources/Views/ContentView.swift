import SwiftUI

/// Main content view.
/// Default page (index 0): solid black screen — this is what iOS shows when any widget
/// tap opens the host app without a specific deep link. Swiping left reveals the
/// widget configuration UI so the black screen acts as a transparent pass-through.
struct ContentView: View {

    @StateObject private var viewModel = WidgetViewModel()
    @State private var showOnboarding = !SharedStorage.shared.hasCompletedOnboarding
    @State private var activeLauncher: LauncherConfig?

    var body: some View {
        TabView {
            // Page 0 — black screen (default when opened via widget tap)
            Color.black
                .ignoresSafeArea()

            // Page 1 — widget configuration (swipe left to access)
            NavigationStack {
                if showOnboarding {
                    OnboardingView(showOnboarding: $showOnboarding)
                } else {
                    WidgetListView()
                }
            }
            .environmentObject(viewModel)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .preferredColorScheme(.dark)
        .tint(.gray)
        .fullScreenCover(item: $activeLauncher) { launcher in
            LauncherGridView(config: launcher) {
                activeLauncher = nil
            }
        }
        .onOpenURL { url in
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "widgetar" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if url.host == "launcher" {
            let idParam = comps?.queryItems?.first(where: { $0.name == "id" })?.value
            if let idParam, let uuid = UUID(uuidString: idParam) {
                activeLauncher = viewModel.launcherConfigs.first(where: { $0.id == uuid })
            } else if let backTapID = SharedStorage.shared.backTapLauncherID,
                      let uuid = UUID(uuidString: backTapID) {
                activeLauncher = viewModel.launcherConfigs.first(where: { $0.id == uuid })
            } else {
                activeLauncher = viewModel.launcherConfigs.first
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var showOnboarding: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                Text("Welcome to Widget")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Create custom widgets for your Home Screen, Lock Screen, and Control Center")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "square.grid.2x2",  title: "Home Screen Widgets", description: "Small, Medium, Large sizes")
                FeatureRow(icon: "lock.display",      title: "Lock Screen Widgets",  description: "Inline, Circular, Rectangular")
                FeatureRow(icon: "hand.tap",          title: "Interactive Actions",  description: "URL schemes, App Actions, Shortcuts")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                SharedStorage.shared.hasCompletedOnboarding = true
                showOnboarding = false
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.black)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}

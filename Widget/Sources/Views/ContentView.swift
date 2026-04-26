import SwiftUI

/// Main content view - entry point for the app
struct ContentView: View {
    
    @StateObject private var viewModel = WidgetViewModel()
    @State private var showOnboarding = !SharedStorage.shared.hasCompletedOnboarding
    @State private var navigateToSettings = false
    
    var body: some View {
        NavigationStack {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
            } else {
                WidgetListView()
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView()
            }
        }
        .environmentObject(viewModel)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigateToSettings = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Welcome icon
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
            
            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "square.grid.2x2", title: "Home Screen Widgets", description: "1×1, 3×3, 6×3, 6×6 sizes")
                FeatureRow(icon: "lock.display", title: "Lock Screen Widgets", description: "Inline, Circular, Rectangular")
                FeatureRow(icon: "hand.tap", title: "Interactive Actions", description: "URL schemes, App Intents, Shortcuts")
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Get Started button
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
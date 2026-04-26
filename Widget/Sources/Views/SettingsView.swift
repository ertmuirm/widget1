import SwiftUI
import UIKit

/// Settings and preferences view
struct SettingsView: View {
    
    @EnvironmentObject var viewModel: WidgetViewModel
    @AppStorage("showItemLabels") private var showItemLabels = true
    @AppStorage("defaultWidgetSize") private var defaultWidgetSize = "systemMedium"
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    
    var body: some View {
        List {
            // General section
            Section("General") {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
                    .foregroundStyle(.white)
                
                Picker("Default Widget Size", selection: $defaultWidgetSize) {
                    ForEach(WidgetSize.allCases, id: \.rawValue) { size in
                        Text(size.displayName).tag(size.rawValue)
                    }
                }
            }
            
            // Widget section
            Section("Widgets") {
                Toggle("Show Item Labels", isOn: $showItemLabels)
                    .foregroundStyle(.white)
                
                NavigationLink(destination: WidgetPreviewSettingsView()) {
                    Label("Preview Settings", systemImage: "eye")
                }
                .foregroundStyle(.white)
            }
            
            // About section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("136")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Backup/Restore section
            Section("Backup & Restore") {
                Button {
                    exportConfigurations()
                } label: {
                    Label("Export Widgets", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(.white)
                
                Button {
                    importConfigurations()
                } label: {
                    Label("Import Widgets", systemImage: "square.and.arrow.down")
                }
                .foregroundStyle(.white)
                
                Button {
                    viewModel.configurations.removeAll()
                    try? SharedStorage.shared.deleteAllConfigurations()
                } label: {
                    Label("Clear All Widgets", systemImage: "trash")
                }
                .foregroundStyle(.red)
            }
            }
            
            // Support section
            Section("Support") {
                Link(destination: URL(string: "https://github.com/iosmirror/widget")!) {
                    Label("GitHub", systemImage: "link")
                }
                .foregroundStyle(.white)
                
                Link(destination: URL(string: "mailto:support@iosmirror.com")!) {
                    Label("Contact", systemImage: "envelope")
                }
                .foregroundStyle(.white)
            }
            
            // Debug section (only in DEBUG)
            #if DEBUG
            Section("Debug") {
                Button(role: .destructive) {
                    // Delete all configurations
                    viewModel.deleteAllConfigurations()
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                }
                .foregroundStyle(.red)
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .preferredColorScheme(.dark)
    }
    
    private func deleteAllConfigurations() {
        viewModel.deleteConfiguration(at: IndexSet(0..<viewModel.configurations.count))
    }
}

// MARK: - Widget Preview Settings

struct WidgetPreviewSettingsView: View {
    @AppStorage("previewBackground") private var previewBackground = true
    
    var body: some View {
        List {
            Section {
                Toggle("Show Background", isOn: $previewBackground)
                    .foregroundStyle(.white)
            } header: {
                Text("Widget Preview")
            } footer: {
                Text("Toggle whether the widget preview shows the configured background color.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Preview")
        .preferredColorScheme(.dark)
    }
}

// MARK: - Theme Colors

/// App theme colors
enum ThemeColors {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.gray
    static let accent = Color.blue
    static let destructive = Color.red
    
    static let cardBackground = Color(white: 0.1)
    static let divider = Color(white: 0.2)
}

// MARK: - Theme Styles

extension View {
    func themeCard() -> some View {
        self
            .padding()
            .background(ThemeColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Export/Import Functions
    
    private func exportConfigurations() {
        guard !viewModel.configurations.isEmpty else { return }
        
        do {
            let data = try JSONEncoder().encode(viewModel.configurations)
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            UIPasteboard.general.string = jsonString
            print("[SettingsView] Exported \(viewModel.configurations.count) configs")
        } catch {
            print("[SettingsView] Export error: \(error)")
        }
    }
    
    private func importConfigurations() {
        guard let jsonString = UIPasteboard.general.string,
              let data = jsonString.data(using: .utf8) else { return }
        
        do {
            let configs = try JSONDecoder().decode([WidgetConfig].self, from: data)
            viewModel.configurations = configs
            try SharedStorage.shared.saveConfigurations(configs)
            print("[SettingsView] Imported \(configs.count) configs")
        } catch {
            print("[SettingsView] Import error: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(WidgetViewModel())
    .preferredColorScheme(.dark)
}
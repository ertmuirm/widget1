import SwiftUI

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
                    Text("1")
                        .foregroundStyle(.secondary)
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
            
            // Backup section
            Section("Backup & Restore") {
                Button {
                    backupConfigs()
                } label: {
                    Label("Backup Configurations", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(.green)
                
                Button {
                    restoreConfigs()
                } label: {
                    Label("Restore Configurations", systemImage: "square.and.arrow.down")
                }
                .foregroundStyle(.blue)
                
                Text("Backup files saved to: Files/On My iPhone/Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Debug section (only in DEBUG)
            #if DEBUG
            Section("Debug") {
                Button(role: .destructive) {
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
    
    private func backupConfigs() {
        do {
            let configs = try SharedStorage.shared.loadConfigurations()
            guard !configs.isEmpty else { return }
            let json = try SharedStorage.shared.exportToJSON(configs)
            
            // Save to UserDefaults
            UserDefaults.standard.set(json, forKey: "widgetBackup")
            
            // Save to Files app "Start" folder
            saveToStartFolder(json: json)
        } catch {
            print("Backup failed: \(error)")
        }
    }
    
    private func saveToStartFolder(json: Data) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = formatter.string(from: Date())
        let fileName = "widget_backup_\(dateStr).json"
        
        // Try to save to the Start folder in Files
        // The "Start" folder is typically at this path
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let docsURL = paths.first else { return }
        
        // Check if Start folder exists, create if not
        let startFolder = docsURL.appendingPathComponent("Start", isDirectory: true)
        if !FileManager.default.fileExists(atPath: startFolder.path) {
            try? FileManager.default.createDirectory(at: startFolder, withIntermediateDirectories: true)
        }
        
        let fileURL = startFolder.appendingPathComponent(fileName)
        do {
            try json.write(to: fileURL)
            print("✅ Backup saved to: \(fileURL.path)")
        } catch {
            print("❌ Failed to save to Start folder: \(error)")
        }
    }
    
    private func restoreConfigs() {
        // Try UserDefaults backup first
        if let data = UserDefaults.standard.data(forKey: "widgetBackup") {
            do {
                let configs = try SharedStorage.shared.importFromJSON(data)
                try SharedStorage.shared.saveConfigurations(configs)
                return
            } catch {
                print("Restore from UserDefaults failed: \(error)")
            }
        }
        
        // Try Start folder
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let docsURL = paths.first {
            let startFolder = docsURL.appendingPathComponent("Start", isDirectory: true)
            do {
                let files = try FileManager.default.contentsOfDirectory(at: startFolder, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("widget_backup") }
                    .sorted { $0.path > $1.path }
                
                if let latestFile = files.first {
                    let data = try Data(contentsOf: latestFile)
                    let configs = try SharedStorage.shared.importFromJSON(data)
                    try SharedStorage.shared.saveConfigurations(configs)
                }
            } catch {
                print("Restore from Start folder failed: \(error)")
            }
        }
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
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(WidgetViewModel())
    .preferredColorScheme(.dark)
}
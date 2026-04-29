import SwiftUI
import WidgetKit

/// Settings and preferences view
struct SettingsView: View {

    @EnvironmentObject var viewModel: WidgetViewModel

    // Bindings backed by SharedStorage so the widget extension can read them via the app group
    private var showItemLabels: Binding<Bool> {
        Binding(
            get: { SharedStorage.shared.showItemLabels },
            set: { newVal in
                SharedStorage.shared.showItemLabels = newVal
                // Bake value into every config so it travels via the embedded entity
                // ID and is readable by the extension without cross-process IPC.
                let updated = viewModel.configurations.map { c -> WidgetConfig in
                    var copy = c; copy.showItemLabels = newVal; return copy
                }
                try? SharedStorage.shared.saveConfigurations(updated)
                viewModel.configurations = updated
                WidgetCenter.shared.reloadAllTimelines()
            }
        )
    }

    private var hapticFeedbackEnabled: Binding<Bool> {
        Binding(
            get: { SharedStorage.shared.hapticFeedback },
            set: { SharedStorage.shared.hapticFeedback = $0 }
        )
    }

    @AppStorage("defaultWidgetSize") private var defaultWidgetSize = "systemMedium"

    @State private var backupAlertMessage = ""
    @State private var showBackupAlert = false
    @State private var backupAlertIsError = false

    var body: some View {
        List {
            // General
            Section("General") {
                Toggle("Haptic Feedback", isOn: hapticFeedbackEnabled)
                    .foregroundStyle(.white)

                Picker("Default Widget Size", selection: $defaultWidgetSize) {
                    ForEach(WidgetSize.homeScreenCases, id: \.rawValue) { size in
                        Text(size.displayName).tag(size.rawValue)
                    }
                }
            }

            // Widgets
            Section {
                Toggle("Show Item Labels", isOn: showItemLabels)
                    .foregroundStyle(.white)

                NavigationLink(destination: WidgetPreviewSettingsView()) {
                    Label("Preview Settings", systemImage: "eye")
                }
                .foregroundStyle(.white)
            } header: {
                Text("Widgets")
            } footer: {
                Text("\"Show Item Labels\" is read by the widget extension via the shared app group. With SideStore (free account), this only takes effect once the app group container is properly shared between the app and the extension.")
                    .font(.caption)
            }

            // Backup & Restore
            Section("Backup & Restore") {
                Button {
                    backupConfigs()
                } label: {
                    Label("Backup to Files", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(.gray)

                Button {
                    restoreConfigs()
                } label: {
                    Label("Restore from Backup", systemImage: "square.and.arrow.down")
                }
                .foregroundStyle(.gray)

                if let lastBackup = SharedStorage.shared.lastBackupDate {
                    HStack {
                        Text("Last Backup")
                        Spacer()
                        Text(lastBackup, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Backup file location: On My iPhone / Widget / widget_backup.json")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Debug (DEBUG only)
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
        .alert(backupAlertIsError ? "Error" : "Success",
               isPresented: $showBackupAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupAlertMessage)
        }
    }

    // MARK: - Backup / Restore

    private func backupConfigs() {
        do {
            if let url = try SharedStorage.shared.createBackup() {
                backupAlertMessage = "Backup saved to:\nOn My iPhone / Widget / \(url.lastPathComponent)"
                backupAlertIsError = false
            } else {
                backupAlertMessage = "No widget configurations to back up."
                backupAlertIsError = false
            }
        } catch {
            backupAlertMessage = "Backup failed: \(error.localizedDescription)"
            backupAlertIsError = true
        }
        showBackupAlert = true
    }

    private func restoreConfigs() {
        do {
            if try SharedStorage.shared.restoreFromBackup() {
                viewModel.loadConfigurations()
                WidgetCenter.shared.reloadAllTimelines()
                backupAlertMessage = "Configurations restored successfully."
                backupAlertIsError = false
            } else {
                backupAlertMessage = "No backup file found.\n\nExpected location:\nOn My iPhone / Widget / widget_backup.json"
                backupAlertIsError = true
            }
        } catch {
            backupAlertMessage = "Restore failed: \(error.localizedDescription)"
            backupAlertIsError = true
        }
        showBackupAlert = true
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

enum ThemeColors {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.gray
    static let accent = Color.gray
    static let cardBackground = Color(white: 0.1)
    static let divider = Color(white: 0.2)
}

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

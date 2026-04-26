import SwiftUI
import WidgetKit

enum AppGroup {
    static let rawId = "group.com.iosmirror"
    static let teamId = "J3D2F4SMVD"
    
    static var suiteName: String {
        let sideStoreId1 = "group.com.iosmirror.\(teamId)"
        let sideStoreId2 = "group.\(teamId).com.iosmirror"
        let rawId = "group.com.iosmirror"
        
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sideStoreId1) {
            print("✅ Active App Group (SideStore1): \(sideStoreId1)")
            print("📂 Container Path: \(container.path)")
            return sideStoreId1
        }
        else if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sideStoreId2) {
            print("✅ Active App Group (SideStore2): \(sideStoreId2)")
            print("📂 Container Path: \(container.path)")
            return sideStoreId2
        }
        else if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: rawId) {
            print("✅ Active App Group (Original): \(rawId)")
            return rawId
        }
        
        print("❌ CRITICAL ERROR: No valid App Group container found for either ID.")
        return rawId
    }
}

/// Floating debug overlay that shows app group data status
struct DebugOverlayView: View {
    
    @State private var statusText = "Checking..."
    @State private var showingExport = false
    @State private var showingImport = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG OVERLAY")
                .font(.headline.bold())
                .foregroundStyle(.red)
            
            Divider()
            
            ScrollView {
                Text(statusText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 150, maxHeight: 200)
            
            Divider()
            
            HStack {
                Button("Refresh") {
                    checkAppGroupData()
                }
                .font(.caption)
                
                Spacer()
                
                Button("Detect") {
                    detectAppGroup()
                }
                .font(.caption)
                .foregroundStyle(.yellow)
            }
            
            HStack {
                Button("Save Test") {
                    saveTestData()
                }
                .font(.caption)
                
                Spacer()
                
                Button("Backup") {
                    backupData()
                }
                .font(.caption)
                .foregroundStyle(.green)
            }
            
            HStack {
                Button("Load") {
                    checkAppGroupData()
                }
                .font(.caption)
                
                Spacer()
                
                Button("Restore") {
                    restoreData()
                }
                .font(.caption)
                .foregroundStyle(.cyan)
            }
        }
        .padding(16)
        .frame(minWidth: 300, minHeight: 280)
        .background(.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            checkAppGroupData()
        }
    }
    
    private func checkAppGroupData() {
        let appGroupID = StorageKeys.appGroupIdentifier
        statusText = "App Group: \(appGroupID)\n"
        
        // Check 1: Container URL
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            statusText += "✅ Container: exists\n"
            statusText += "Path: \(containerURL.path)\n"
            
            // Check for configurations.json
            let configURL = containerURL.appendingPathComponent("configurations.json")
            if FileManager.default.fileExists(atPath: configURL.path) {
                statusText += "✅ File: exists\n"
                
                if let data = try? Data(contentsOf: configURL),
                   let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) {
                    statusText += "Config count: \(configs.count)\n"
                    for config in configs {
                        statusText += "- \(config.name)\n"
                    }
                }
            } else {
                statusText += "❌ File: not found\n"
            }
        } else {
            statusText += "❌ Container: access denied\n"
        }
        
        statusText += "---UserDefaults---\n"
        
        // Check 2: UserDefaults
        if let defaults = UserDefaults(suiteName: appGroupID) {
            statusText += "✅ UserDefaults: accessible\n"
            
            if let data = defaults.data(forKey: "widgetConfigurations") {
                statusText += "✅ Data key exists: \(data.count) bytes\n"
                
                if let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) {
                    statusText += "Config count: \(configs.count)\n"
                    for config in configs {
                        statusText += "- \(config.name)\n"
                    }
                }
            } else {
                statusText += "❌ Data key: empty or nil\n"
            }
        } else {
            statusText += "❌ UserDefaults: access denied\n"
        }
        
        // Force trigger refresh
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func saveTestData() {
        let testItem = WidgetItem(
            id: UUID(),
            displayType: .text,
            customText: "Hello!"
        )
        let testConfig = WidgetConfig(
            id: UUID(),
            name: "Test",
            size: .systemSmall,
            items: [testItem]
        )
        
        do {
            try SharedStorage.shared.saveConfigurations([testConfig])
            statusText = "✅ Saved test data!\n"
            checkAppGroupData()
        } catch {
            statusText = "❌ Save failed: \(error.localizedDescription)"
        }
    }
    
    private func detectAppGroup() {
        let teamId = "J3D2F4SMVD"
        let rawId = "group.com.iosmirror"
        let sideStoreId1 = "group.com.iosmirror.\(teamId)"
        let sideStoreId2 = "group.\(teamId).com.iosmirror"
        
        statusText = "---App Group Detection---\n"
        
        for id in [sideStoreId1, sideStoreId2, rawId] {
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                statusText += "✅ \(id)\n"
                statusText += "Path: \(container.path)\n"
            } else {
                statusText += "❌ \(id)\n"
            }
        }
        
        let active = AppGroup.suiteName
        statusText += "---Active: \(active)---\n"
    }
    
    private func backupData() {
        do {
            let configs = try SharedStorage.shared.loadConfigurations()
            guard !configs.isEmpty else {
                statusText = "⚠️ No configs to backup"
                return
            }
            
            let json = try SharedStorage.shared.exportToJSON(configs)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let dateStr = formatter.string(from: Date())
            let fileName = "widget_backup_\(dateStr).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try json.write(to: tempURL)
            
            statusText = "✅ Backup saved!\n\(fileName)\n"
            statusText += "Size: \(json.count) bytes\n"
            
            // Try to save to documents for sharing
            if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let backupURL = docsURL.appendingPathComponent("widget_backup.json")
                try json.write(to: backupURL)
                statusText += "Saved to: \(backupURL.lastPathComponent)\n"
            } else {
                statusText += "❌ Could not save to Documents"
            }
        } catch {
            statusText = "❌ Backup failed: \(error.localizedDescription)"
        }
    }
    
    private func restoreData() {
        do {
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let backupURL = docsURL?.appendingPathComponent("widget_backup.json")
            
            guard let url = backupURL, FileManager.default.fileExists(atPath: url.path) else {
                statusText = "⚠️ No backup file found"
                return
            }
            
            let data = try Data(contentsOf: url)
            let configs = try SharedStorage.shared.importFromJSON(data)
            try SharedStorage.shared.saveConfigurations(configs)
            
            statusText = "✅ Restored \(configs.count) configs!\n"
        } catch {
            statusText = "❌ Restore failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    DebugOverlayView()
}
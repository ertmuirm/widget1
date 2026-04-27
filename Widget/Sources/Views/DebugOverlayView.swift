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
    
    private func checkAppGroupData() {
        let info = try? SharedStorage.shared.getStorageInfo()
        let group = SharedStorage.shared.activeAppGroup
        let count = info?.configurationCount ?? 0
        
        statusText = "---Status---\n"
        statusText += "App Group: \(group)\n"
        statusText += "Mode: UserDefaults\n"
        statusText += "Configs: \(count)\n"
        statusText += "Size: \(info?.size ?? 0) bytes\n"
    }
    
    private func detectAppGroup() {
        let teamId = "J3D2F4SMVD"
        let rawId = "group.com.iosmirror"
        let sideStoreId1 = "group.com.iosmirror.\(teamId)"
        let sideStoreId2 = "group.\(teamId).com.iosmirror"
        
        statusText = "---App Group Detection (UD)---\n"
        
        // Test UserDefaults
        for id in [sideStoreId1, sideStoreId2, rawId, "standard"] {
            if let ud = UserDefaults(suiteName: id) {
                ud.set("test", forKey: "_test")
                if ud.string(forKey: "_test") == "test" {
                    ud.removeObject(forKey: "_test")
                    statusText += "✅ \(id)\n"
                } else {
                    statusText += "❌ \(id)\n"
                }
            } else if id == "standard" {
                UserDefaults.standard.set("test", forKey: "_test")
                if UserDefaults.standard.string(forKey: "_test") == "test" {
                    UserDefaults.standard.removeObject(forKey: "_test")
                    statusText += "✅ standard\n"
                } else {
                    statusText += "❌ standard\n"
                }
            } else {
                statusText += "❌ \(id) (nil)\n"
            }
        }
    }
    
    private func backupData() {
        do {
            let configs = try SharedStorage.shared.loadConfigurations()
            guard !configs.isEmpty else {
                statusText = "⚠️ No configs to backup"
                return
            }
            
            let json = try SharedStorage.shared.exportToJSON(configs)
            
            // Save to standard UserDefaults for sharing
            UserDefaults.standard.set(json, forKey: "widgetBackup")
            
            // Also try to save to Documents
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let dateStr = formatter.string(from: Date())
            let fileName = "widget_backup_\(dateStr).json"
            
            if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let backupURL = docsURL.appendingPathComponent(fileName)
                do {
                    try json.write(to: backupURL)
                    statusText = "✅ Backup saved!\n\(fileName)\nSize: \(json.count) bytes\n"
                } catch {
                    statusText = "✅ Saved to UserDefaults!\nConfigs: \(configs.count)\nFile: \(fileName)"
                }
            } else {
                statusText = "✅ Saved to UserDefaults!\nConfigs: \(configs.count)"
            }
        } catch {
            statusText = "❌ Backup failed: \(error.localizedDescription)"
        }
    }
    
    private func restoreData() {
        do {
            // Try UserDefaults backup first
            var data: Data? = UserDefaults.standard.data(forKey: "widgetBackup")
            
            // If not found, try Documents
            if data == nil {
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                if let url = docsURL?.listing(pathsWithPrefix: "widget_backup").first {
                    data = try? Data(contentsOf: url)
                }
            }
            
            guard let json = data else {
                statusText = "⚠️ No backup found"
                return
            }
            
            let configs = try SharedStorage.shared.importFromJSON(json)
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
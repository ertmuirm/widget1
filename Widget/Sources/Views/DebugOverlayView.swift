import SwiftUI
import WidgetKit

/// Floating debug overlay that shows app group data status
struct DebugOverlayView: View {
    
    @State private var statusText = "Checking..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG OVERLAY")
                .font(.caption.bold())
                .foregroundStyle(.red)
            
            Divider()
            
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.white)
            
            Divider()
            
            Button("Refresh") {
                checkAppGroupData()
            }
            .font(.caption)
            
            Button("Detect App Group") {
                detectAppGroup()
            }
            .font(.caption)
            
            HStack {
                Button("Save Test") {
                    saveTestData()
                }
                .font(.caption)
                
                Spacer()
                
                Button("Load") {
                    checkAppGroupData()
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
}

#Preview {
    DebugOverlayView()
}
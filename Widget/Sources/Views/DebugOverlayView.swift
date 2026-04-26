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
        statusText = "App Group ID: \(appGroupID)\n"
        
        // Check standard UserDefaults
        let defaults = UserDefaults.standard
        statusText += "---UserDefaults.standard---\n"
        
        if let data = defaults.data(forKey: "widgetConfigurations") {
            statusText += "✅ Data: \(data.count) bytes\n"
            
            if let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) {
                statusText += "Configs: \(configs.count)\n"
                for config in configs {
                    statusText += "- \(config.name)\n"
                }
            }
        } else {
            statusText += "❌ No data yet\n"
        }
        
        // Check App Group container
        statusText += "---Container---\n"
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            statusText += "✅ Container available\n"
        } else {
            statusText += "❌ Container not available\n"
        }
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
}

#Preview {
    DebugOverlayView()
}
import SwiftUI

/// View to display debug logs in-app
struct DebugLogView: View {
    
    @StateObject private var logManager = DebugLogManager.shared
    @State private var showFileContent = false
    @State private var fileContent = ""
    
    var body: some View {
        List {
            Section {
                ForEach(logManager.logs.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.category)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                            Spacer()
                            Text(formatTime(entry.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.message)
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("In-Memory Logs (\(logManager.logs.count))")
                    Spacer()
                    Button("Clear") {
                        logManager.clearLogs()
                    }
                    .font(.caption)
                }
            }
            
            Section {
                Button {
                    loadFileContent()
                } label: {
                    Label("View Log File", systemImage: "doc.text")
                }

                Button {
                    exportLogs()
                } label: {
                    Label("Export Logs", systemImage: "square.and.arrow.up")
                }

                Button {
                    fileContent = SharedStorage.shared.readExtensionLog()
                    showFileContent = true
                } label: {
                    Label("Extension Log (cross-process)", systemImage: "arrow.triangle.2.circlepath")
                }

                Button(role: .destructive) {
                    SharedStorage.shared.clearExtensionLog()
                } label: {
                    Label("Clear Extension Log", systemImage: "trash")
                }
                .foregroundStyle(.red)
            } header: {
                Text("File-based Logs")
            } footer: {
                Text("Extension log is written by both the app and the widget extension to all accessible app groups.")
            }

            if showFileContent {
                Section("Log Content") {
                    ScrollView {
                        Text(fileContent)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Debug Logs")
        .preferredColorScheme(.dark)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func loadFileContent() {
        if let url = logManager.logFileURL,
           let content = try? String(contentsOf: url, encoding: .utf8) {
            fileContent = content
            showFileContent = true
        } else {
            fileContent = "No log file found"
            showFileContent = true
        }
    }
    
    private func exportLogs() {
        let content = logManager.exportLogs()
        UIPasteboard.general.string = content
    }
}

#Preview {
    NavigationStack {
        DebugLogView()
    }
    .preferredColorScheme(.dark)
}
import Foundation
import WidgetKit

/// Debug log manager - writes logs to file for viewing without Xcode
final class DebugLogManager: ObservableObject {
    static let shared = DebugLogManager()
    
    @Published var logs: [LogEntry] = []
    
    private let maxLogs = 100
    private let logFileName = "debug.log"
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let category: String
    }
    
    private init() {}
    
    var logFileURL: URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: StorageKeys.appGroupIdentifier) else {
            return nil
        }
        return containerURL.appendingPathComponent(logFileName)
    }
    
    func log(_ message: String, category: String = "App") {
        let entry = LogEntry(timestamp: Date(), message: message, category: category)
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst()
            }
        }
        
        // Also write to file
        if let url = logFileURL {
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            let line = "[\(timestamp)] [\(category)] \(message)\n"
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: url.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: url) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
        
        // Also print for console
        print("[\(category)] \(message)")
    }
    
    func clearLogs() {
        logs.removeAll()
        if let url = logFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func exportLogs() -> String {
        logs.map { entry in
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            return "[\(timestamp)] [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

// Convenience functions
func debugLog(_ message: String, category: String = "App") {
    DebugLogManager.shared.log(message, category: category)
}
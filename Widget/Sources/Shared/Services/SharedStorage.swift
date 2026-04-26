import Foundation

/// Service for storing widget configurations in App Group shared container
final class SharedStorage {
    
    static let shared = SharedStorage()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var containerURL: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: StorageKeys.appGroupIdentifier)
    }
    
    private var configurationsURL: URL? {
        containerURL?.appendingPathComponent("configurations.json")
    }
    
    private init() {
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Widget Configurations
    
    /// Save all widget configurations
    func saveConfigurations(_ configurations: [WidgetConfig]) throws {
        guard let url = configurationsURL else {
            print("[SharedStorage] ERROR: configurationsURL is nil")
            throw StorageError.containerNotAvailable
        }
        
        print("[SharedStorage.saveConfigurations] Saving \(configurations.count) configs")
        print("[SharedStorage.saveConfigurations] URL: \(url.path)")
        
        let data = try encoder.encode(configurations)
        print("[SharedStorage.saveConfigurations] Encoded data size: \(data.count) bytes")
        
        do {
            try data.write(to: url, options: .atomic)
            print("[SharedStorage.saveConfigurations] File write SUCCESS")
        } catch {
            print("[SharedStorage.saveConfigurations] ERROR writing file: \(error)")
            throw error
        }
        
        // Sync to shared UserDefaults for widget extension (EntityQuery)
        // Use standard UserDefaults (not suiteName) for immediate availability
        let appGroupID = StorageKeys.appGroupIdentifier
        print("[SharedStorage.saveConfigurations] Using App Group: \(appGroupID)")
        
        if let defaults = UserDefaults(suiteName: appGroupID) {
            // Force remove any cached data first
            defaults.removeObject(forKey: "widgetConfigurations")
            defaults.set(data, forKey: "widgetConfigurations")
            let syncResult = defaults.synchronize()
            print("[SharedStorage.saveConfigurations] UserDefaults synchronize: \(syncResult)")
            
            // Verify it was set
            let verifyData = defaults.data(forKey: "widgetConfigurations")
            print("[SharedStorage.saveConfigurations] Verified data: \(verifyData?.count ?? 0) bytes")
        } else {
            print("[SharedStorage.saveConfigurations] ERROR: Failed to access App Group UserDefaults")
        }
        
        // Also write to debug log file
        let logEntry = """
        [\(ISO8601DateFormatter().string(from: Date()))] [Storage] Saved \(configurations.count) configs (\(data.count) bytes)
        """
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let logFile = containerURL.appendingPathComponent("debug.log")
            if let logData = logEntry.appending("\n").data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let handle = try? FileHandle(forWritingTo: logFile) {
                        handle.seekToEndOfFile()
                        handle.write(logData)
                        handle.closeFile()
                    }
                } else {
                    try? logData.write(to: logFile)
                }
            }
        }
    }
    
    /// Load all widget configurations
    func loadConfigurations() throws -> [WidgetConfig] {
        guard let url = configurationsURL else {
            throw StorageError.containerNotAvailable
        }
        
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        
        let data = try Data(contentsOf: url)
        return try decoder.decode([WidgetConfig].self, from: data)
    }
    
    /// Delete all configurations
    func deleteAllConfigurations() throws {
        guard let url = configurationsURL else {
            throw StorageError.containerNotAvailable
        }
        
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    // MARK: - Onboarding
    
    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: StorageKeys.hasCompletedOnboarding)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKeys.hasCompletedOnboarding)
        }
    }
    
    // MARK: - Backup Date
    
    var lastBackupDate: Date? {
        get {
            UserDefaults.standard.object(forKey: StorageKeys.lastBackupDate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StorageKeys.lastBackupDate)
        }
    }
    
    // MARK: - Export/Import
    
    /// Export configurations to JSON data
    func exportToJSON(_ configurations: [WidgetConfig]) throws -> Data {
        let exportData = ExportData(configurations: configurations)
        return try encoder.encode(exportData)
    }
    
    /// Import configurations from JSON data
    func importFromJSON(_ data: Data) throws -> [WidgetConfig] {
        let exportData = try decoder.decode(ExportData.self, from: data)
        return exportData.configurations
    }
    
    // MARK: - Storage Info
    
    /// Get storage usage information
    func getStorageInfo() throws -> StorageInfo {
        guard let url = configurationsURL else {
            throw StorageError.containerNotAvailable
        }
        
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let size = attributes?[.size] as? Int64 ?? 0
        
        return StorageInfo(
            fileExists: fileManager.fileExists(atPath: url.path),
            size: size,
            configurationCount: (try? loadConfigurations().count) ?? 0
        )
    }
}

// MARK: - Storage Info

struct StorageInfo {
    let fileExists: Bool
    let size: Int64
    let configurationCount: Int
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case containerNotAvailable
    case encodingFailed
    case decodingFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .containerNotAvailable:
            return "App Group container is not available"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        case .fileNotFound:
            return "File not found"
        }
    }
}
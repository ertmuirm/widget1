import Foundation

/// Service for storing widget configurations in App Group shared container
final class SharedStorage {
    
    static let shared = SharedStorage()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // App Group IDs to try
    private let appGroupIDs = [
        "group.com.iosmirror.J3D2F4SMVD",
        "group.J3D2F4SMVD.com.iosmirror", 
        "group.com.iosmirror"
    ]
    
    // Storage mode
    private var useFileStorage = false
    private var activeAppGroupID: String = "group.com.iosmirror"
    
    // UserDefaults reference (use whichever works)
    private var sharedDefaults: UserDefaults? {
        for id in appGroupIDs {
            if let defaults = UserDefaults(suiteName: id) {
                // Test if it works
                defaults.set("test", forKey: "_test_key")
                if defaults.string(forKey: "_test_key") == "test" {
                    defaults.removeObject(forKey: "_test_key")
                    print("✅ Using UserDefaults: \(id)")
                    activeAppGroupID = id
                    return defaults
                }
            }
        }
        // Fallback to standard
        print("⚠️ Falling back to standard UserDefaults")
        activeAppGroupID = "standard"
        return UserDefaults.standard
    }
    
    private var containerURL: URL? {
        guard useFileStorage else { return nil }
        for id in appGroupIDs {
            if let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: id) {
                let testFile = url.appendingPathComponent(".test")
                if fileManager.createFile(atPath: testFile.path, contents: nil) {
                    try? fileManager.removeItem(at: testFile)
                    print("✅ Using file container: \(id)")
                    activeAppGroupID = id
                    return url
                }
            }
        }
        return nil
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
        let data = try encoder.encode(configurations)
        
        // Use UserDefaults (works even without container)
        sharedDefaults?.set(data, forKey: "widgetConfigurations")
        
        print("✅ Saved \(configurations.count) configs to UserDefaults")
    }
    
    /// Load all widget configurations
    func loadConfigurations() throws -> [WidgetConfig] {
        guard let data = sharedDefaults?.data(forKey: "widgetConfigurations") else {
            return []
        }
        
        return try decoder.decode([WidgetConfig].self, from: data)
    }
    
    /// Delete all configurations
    func deleteAllConfigurations() throws {
        sharedDefaults?.removeObject(forKey: "widgetConfigurations")
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
        let configs = try loadConfigurations()
        let size = sharedDefaults?.data(forKey: "widgetConfigurations")?.count ?? 0
        
        return StorageInfo(
            fileExists: true,
            size: Int64(size),
            configurationCount: configs.count
        )
    }
    
    /// Get active App Group ID
    var activeAppGroup: String {
        activeAppGroupID
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
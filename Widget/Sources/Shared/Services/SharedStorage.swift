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
            throw StorageError.containerNotAvailable
        }
        
        let data = try encoder.encode(configurations)
        try data.write(to: url, options: .atomic)
        
        // Also save to UserDefaults for widget extension access
        if let defaults = UserDefaults(suiteName: StorageKeys.appGroupIdentifier) {
            defaults.set(data, forKey: "widgetConfigurations")
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
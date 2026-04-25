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
    func saveConfigurations(_ configurations: [WidgetConfiguration]) throws {
        guard let url = configurationsURL else {
            throw StorageError.containerNotAvailable
        }
        
        let data = try encoder.encode(configurations)
        try data.write(to: url, options: .atomic)
    }
    
    /// Load all widget configurations
    func loadConfigurations() throws -> [WidgetConfiguration] {
        guard let url = configurationsURL else {
            throw StorageError.containerNotAvailable
        }
        
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        
        let data = try Data(contentsOf: url)
        return try decoder.decode([WidgetConfiguration].self, from: data)
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
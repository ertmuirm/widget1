import Foundation

/// Unified storage for widget configurations - works for both app and extension
final class SharedStorage {
    
    static let shared = SharedStorage()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Fixed key for configurations
    static let configKey = "widgetConfigurations"
    
    // Static cache for App Group ID - shared between all instances
    private static var cachedAppGroupID: String?
    
    /// Get active App Group ID (cached for consistency)
    var activeAppGroupID: String {
        if let cached = SharedStorage.cachedAppGroupID {
            return cached
        }
        
        let ids = [
            "group.com.iosmirror.J3D2F4SMVD",
            "group.J3D2F4SMVD.com.iosmirror",
            "group.com.iosmirror"
        ]
        
        for id in ids {
            if let defaults = UserDefaults(suiteName: id) {
                defaults.set("test", forKey: "_test")
                if defaults.string(forKey: "_test") == "test" {
                    defaults.removeObject(forKey: "_test")
                    SharedStorage.cachedAppGroupID = id
                    print("[Storage] Using: \(id)")
                    return id
                }
            }
        }
        
        SharedStorage.cachedAppGroupID = "standard"
        return "standard"
    }
    
    /// UserDefaults for the cached App Group ID
    private var defaults: UserDefaults? {
        return UserDefaults(suiteName: activeAppGroupID)
    }
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Save/Load
    
    func saveConfigurations(_ configurations: [WidgetConfig]) throws {
        guard let defaults = defaults else {
            throw StorageError.noDefaults
        }
        
        let data = try encoder.encode(configurations)
        defaults.set(data, forKey: Self.configKey)
        defaults.synchronize()
        
        print("[Storage] Saved \(configurations.count) configs (\(data.count) bytes)")
    }
    
    func loadConfigurations() throws -> [WidgetConfig] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: Self.configKey) else {
            print("[Storage] No configs found")
            return []
        }
        
        let configs = try decoder.decode([WidgetConfig].self, from: data)
        print("[Storage] Loaded \(configs.count) configs")
        return configs
    }
    
    func deleteAllConfigurations() throws {
        defaults?.removeObject(forKey: Self.configKey)
        defaults?.synchronize()
    }
    
    // MARK: - Single Config
    
    func getConfig(named name: String) -> WidgetConfig? {
        guard let configs = try? loadConfigurations() else { return nil }
        return configs.first { $0.name == name }
    }
    
    // MARK: - Export/Import
    
    func exportToJSON(_ configurations: [WidgetConfig]) throws -> Data {
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(configurations)
    }
    
    func importFromJSON(_ data: Data) throws -> [WidgetConfig] {
        return try decoder.decode([WidgetConfig].self, from: data)
    }
    
    // MARK: - Info
    
    func getStorageInfo() throws -> StorageInfo {
        let configs = try loadConfigurations()
        let size = defaults?.data(forKey: Self.configKey)?.count ?? 0
        
        return StorageInfo(
            appGroupID: activeAppGroupID,
            configurationCount: configs.count,
            size: size
        )
    }
    
    var activeAppGroup: String {
        return activeAppGroupID
    }
    
    // MARK: - Onboarding (standard UserDefaults)
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}

// MARK: - Storage Info

struct StorageInfo {
    let appGroupID: String
    let configurationCount: Int
    let size: Int
}

// MARK: - Errors

enum StorageError: LocalizedError {
    case noDefaults
    
    var errorDescription: String? {
        switch self {
        case .noDefaults:
            return "UserDefaults not available"
        }
    }
}

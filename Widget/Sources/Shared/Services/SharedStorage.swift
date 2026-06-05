import Foundation

final class SharedStorage {
    
    static let shared = SharedStorage()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    static let configKey = "widgetConfigurations"
    
    private static var cachedAppGroupID: String?
    
    var activeAppGroupID: String {
        if let cached = SharedStorage.cachedAppGroupID {
            return cached
        }
        
        let ids = ["group.com.iosmirror.J3D2F4SMVD", "group.J3D2F4SMVD.com.iosmirror", "group.com.iosmirror"]
        
        for id in ids {
            if let defaults = UserDefaults(suiteName: id) {
                defaults.set("test", forKey: "_test")
                if defaults.string(forKey: "_test") == "test" {
                    defaults.removeObject(forKey: "_test")
                    SharedStorage.cachedAppGroupID = id
                    return id
                }
            }
        }
        
        SharedStorage.cachedAppGroupID = "standard"
        return "standard"
    }
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func saveConfigurations(_ configurations: [WidgetConfig]) throws {
        let data = try encoder.encode(configurations)
        
        if let groupDefaults = UserDefaults(suiteName: activeAppGroupID) {
            groupDefaults.set(data, forKey: Self.configKey)
            groupDefaults.synchronize()
        }
        
        UserDefaults.standard.set(data, forKey: Self.configKey)
    }
    
    func loadConfigurations() throws -> [WidgetConfig] {
        if let groupDefaults = UserDefaults(suiteName: activeAppGroupID),
           let data = groupDefaults.data(forKey: Self.configKey) {
            return try decoder.decode([WidgetConfig].self, from: data)
        }
        
        if let data = UserDefaults.standard.data(forKey: Self.configKey) {
            return try decoder.decode([WidgetConfig].self, from: data)
        }
        
        return []
    }
    
    func getConfig(named name: String) -> WidgetConfig? {
        guard let configs = try? loadConfigurations() else { return nil }
        return configs.first { $0.name == name }
    }
    
    func deleteAllConfigurations() throws {
        UserDefaults.standard.removeObject(forKey: Self.configKey)
    }
    
    func createBackup() throws -> URL? {
        let configs = try loadConfigurations()
        guard !configs.isEmpty else { return nil }
        
        let json = try encoder.encode(configs)
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = docsURL.appendingPathComponent("widget_backup.json")
        try json.write(to: backupURL)
        return backupURL
    }
    
    func restoreFromBackup() throws -> Bool {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = docsURL.appendingPathComponent("widget_backup.json")
        
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return false }
        
        let data = try Data(contentsOf: backupURL)
        let configs = try decoder.decode([WidgetConfig].self, from: data)
        try saveConfigurations(configs)
        return true
    }
    
    func exportToJSON(_ configurations: [WidgetConfig]) throws -> Data {
        return try encoder.encode(configurations)
    }
    
    func importFromJSON(_ data: Data) throws -> [WidgetConfig] {
        return try decoder.decode([WidgetConfig].self, from: data)
    }
    
    func getStorageInfo() throws -> StorageInfo {
        let configs = try loadConfigurations()
        return StorageInfo(
            appGroupID: activeAppGroupID,
            configurationCount: configs.count,
            size: configs.count
        )
    }
    
    var activeAppGroup: String { activeAppGroupID }
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
    
    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastBackupDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastBackupDate") }
    }

    // MARK: - Push Command Storage

    private static let pushCommandKey = "pushCommandEntries"
    private static let ntfyTopicKey   = "ntfyTopic"
    private static let ntfyStatusKey  = "ntfyRegistrationStatus"
    private static let ntfyTokenKey   = "ntfyDeviceToken"

    func savePushCommandEntries(_ entries: [PushCommandEntry]) {
        guard let data = try? encoder.encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.pushCommandKey)
    }

    func loadPushCommandEntries() -> [PushCommandEntry] {
        guard let data = UserDefaults.standard.data(forKey: Self.pushCommandKey),
              let entries = try? decoder.decode([PushCommandEntry].self, from: data) else {
            return []
        }
        return entries
    }

    /// Unique obfuscated topic, generated once and persisted per device.
    var ntfyTopic: String {
        if let stored = UserDefaults.standard.string(forKey: Self.ntfyTopicKey) {
            return stored
        }
        let hex = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(14).lowercased()
        let topic = "bc\(hex)"
        UserDefaults.standard.set(topic, forKey: Self.ntfyTopicKey)
        return topic
    }

    var ntfyRegistrationStatus: String? {
        get { UserDefaults.standard.string(forKey: Self.ntfyStatusKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.ntfyStatusKey) }
    }

    var ntfyDeviceToken: String? {
        get { UserDefaults.standard.string(forKey: Self.ntfyTokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.ntfyTokenKey) }
    }
}

struct StorageInfo {
    let appGroupID: String
    let configurationCount: Int
    let size: Int
}

enum StorageError: Error { case noDefaults }

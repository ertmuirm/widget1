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
    
    var activeAppGroup: String { activeAppGroupID }
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
    
    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastBackupDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastBackupDate") }
    }
}

struct StorageInfo {
    let appGroupID: String
    let configurationCount: Int
    let size: Int
}

enum StorageError: Error { case noDefaults }

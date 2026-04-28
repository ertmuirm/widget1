import Foundation

final class SharedStorage {

    static let shared = SharedStorage()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    static let configKey = "widgetConfigurations"

    // MARK: - App Group Detection

    private static let appGroupCandidates = [
        "group.com.iosmirror.J3D2F4SMVD",
        "group.J3D2F4SMVD.com.iosmirror",
        "group.com.iosmirror"
    ]

    // In-process cache; re-detected on each process launch (extension vs. app share same logic)
    private static var _detectedGroupID: String?

    static var detectedGroupID: String {
        if let cached = _detectedGroupID { return cached }

        for id in appGroupCandidates {
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                let probe = container.appendingPathComponent(".grouptest")
                if FileManager.default.createFile(atPath: probe.path, contents: Data()) {
                    try? FileManager.default.removeItem(at: probe)
                    _detectedGroupID = id
                    return id
                }
            }
        }

        // Fallback: no valid app group found (e.g. simulator without entitlements)
        let fallback = appGroupCandidates.last!
        _detectedGroupID = fallback
        return fallback
    }

    // MARK: - Accessors

    var activeAppGroupID: String { Self.detectedGroupID }
    var activeAppGroup: String { Self.detectedGroupID }

    var groupDefaults: UserDefaults {
        UserDefaults(suiteName: Self.detectedGroupID) ?? .standard
    }

    private var groupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.detectedGroupID)
    }

    // File-based persistence inside the shared container (survives reboot better than UserDefaults alone)
    private var configFileURL: URL? {
        groupContainerURL?.appendingPathComponent("widgetConfigs.json")
    }

    // MARK: - Init

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Configuration CRUD

    func saveConfigurations(_ configurations: [WidgetConfig]) throws {
        let data = try encoder.encode(configurations)

        // 1. App group UserDefaults (fastest path for extension reads)
        groupDefaults.set(data, forKey: Self.configKey)
        groupDefaults.synchronize()

        // 2. File in shared container (persists across reboots more reliably)
        if let url = configFileURL {
            try data.write(to: url, options: .atomicWrite)
        }

        // 3. Standard UserDefaults as last-resort fallback
        UserDefaults.standard.set(data, forKey: Self.configKey)
        UserDefaults.standard.synchronize()
    }

    func loadConfigurations() throws -> [WidgetConfig] {
        // 1. App group UserDefaults
        if let data = groupDefaults.data(forKey: Self.configKey),
           let configs = try? decoder.decode([WidgetConfig].self, from: data) {
            return configs
        }

        // 2. File in shared container
        if let url = configFileURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let configs = try? decoder.decode([WidgetConfig].self, from: data) {
            // Re-populate UserDefaults so next read is fast
            groupDefaults.set(data, forKey: Self.configKey)
            groupDefaults.synchronize()
            return configs
        }

        // 3. Standard UserDefaults
        if let data = UserDefaults.standard.data(forKey: Self.configKey) {
            return try decoder.decode([WidgetConfig].self, from: data)
        }

        return []
    }

    func getConfig(named name: String) -> WidgetConfig? {
        (try? loadConfigurations())?.first { $0.name == name }
    }

    func getConfig(id: String) -> WidgetConfig? {
        (try? loadConfigurations())?.first { $0.id.uuidString == id }
    }

    func deleteAllConfigurations() throws {
        groupDefaults.removeObject(forKey: Self.configKey)
        groupDefaults.synchronize()
        UserDefaults.standard.removeObject(forKey: Self.configKey)
        if let url = configFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Backup / Restore

    /// Saves a backup JSON to On My iPhone / Widget / Start / widget_backup.json
    func createBackup() throws -> URL? {
        let configs = try loadConfigurations()
        guard !configs.isEmpty else { return nil }

        let json = try encoder.encode(configs)

        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let startFolderURL = docsURL.appendingPathComponent("Start", isDirectory: true)

        if !FileManager.default.fileExists(atPath: startFolderURL.path) {
            try FileManager.default.createDirectory(at: startFolderURL, withIntermediateDirectories: true)
        }

        let backupURL = startFolderURL.appendingPathComponent("widget_backup.json")
        try json.write(to: backupURL, options: .atomicWrite)
        lastBackupDate = Date()
        return backupURL
    }

    /// Restores from the backup file in the "Start" subfolder (or root Documents as fallback).
    func restoreFromBackup() throws -> Bool {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let candidates = [
            docsURL.appendingPathComponent("Start/widget_backup.json"),
            docsURL.appendingPathComponent("widget_backup.json")
        ]

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            let configs = try decoder.decode([WidgetConfig].self, from: data)
            try saveConfigurations(configs)
            return true
        }
        return false
    }

    func exportToJSON(_ configurations: [WidgetConfig]) throws -> Data {
        try encoder.encode(configurations)
    }

    func importFromJSON(_ data: Data) throws -> [WidgetConfig] {
        try decoder.decode([WidgetConfig].self, from: data)
    }

    func getStorageInfo() throws -> StorageInfo {
        let configs = try loadConfigurations()
        return StorageInfo(appGroupID: Self.detectedGroupID,
                           configurationCount: configs.count,
                           size: configs.count)
    }

    // MARK: - Preferences (stored in shared group so widget extension can read them)

    var hasCompletedOnboarding: Bool {
        get {
            // Check both stores; standard is fine for this (extension doesn't need it)
            UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding")
        }
    }

    var lastBackupDate: Date? {
        get { groupDefaults.object(forKey: "lastBackupDate") as? Date }
        set { groupDefaults.set(newValue, forKey: "lastBackupDate"); groupDefaults.synchronize() }
    }

    /// Whether widget item labels should be shown below icons (readable by extension via app group)
    var showItemLabels: Bool {
        get { groupDefaults.object(forKey: "showItemLabels") as? Bool ?? true }
        set { groupDefaults.set(newValue, forKey: "showItemLabels"); groupDefaults.synchronize() }
    }

    /// Whether the main app should trigger haptic feedback on actions
    var hapticFeedback: Bool {
        get { groupDefaults.object(forKey: "hapticFeedback") as? Bool ?? true }
        set { groupDefaults.set(newValue, forKey: "hapticFeedback"); groupDefaults.synchronize() }
    }
}

// MARK: - Supporting Types

struct StorageInfo {
    let appGroupID: String
    let configurationCount: Int
    let size: Int
}

enum StorageError: Error { case noDefaults }

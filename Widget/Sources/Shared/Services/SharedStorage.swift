import Foundation

/// Shared persistent storage used by both the main app and the widget extension.
///
/// Design principle: SCATTER writes (write to every accessible app-group candidate
/// simultaneously) and GATHER reads (try every candidate in priority order, return
/// the first that contains valid data). This makes the storage resilient to SideStore
/// re-signing, which may change the active app-group ID to any of the three known
/// formats: `group.com.iosmirror`, `group.com.iosmirror.J3D2F4SMVD`, or
/// `group.J3D2F4SMVD.com.iosmirror`.
final class SharedStorage {

    static let shared = SharedStorage()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Constants

    static let configKey        = "widgetConfigurations"
    static let extensionLogKey  = "widgetExtensionLog"

    /// All app-group candidates, in priority order.
    /// We write to ALL and read from the first that has valid data.
    static let appGroupCandidates: [String] = [
        "group.com.iosmirror.J3D2F4SMVD",   // SideStore: team ID appended
        "group.J3D2F4SMVD.com.iosmirror",   // SideStore: team ID prepended
        "group.com.iosmirror"                // canonical / unsigned
    ]

    // MARK: - Init

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Accessors (for UI display)

    /// The first group candidate that currently contains config data, or the first
    /// with a valid container URL, or the last candidate as a hardcoded fallback.
    var activeAppGroupID: String {
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id), ud.data(forKey: Self.configKey) != nil {
                return id
            }
        }
        for id in Self.appGroupCandidates {
            if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil {
                return id
            }
        }
        return Self.appGroupCandidates.last!
    }

    /// Short diagnostic string listing which group candidates have accessible containers.
    var groupDiagnostic: String {
        let results = Self.appGroupCandidates.map { id -> String in
            let hasContainer = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) != nil
            let hasData = UserDefaults(suiteName: id)?.data(forKey: Self.configKey) != nil
            return "\(id.replacingOccurrences(of: "group.", with: "")): "
                + (hasContainer ? "✓container" : "✗container")
                + " " + (hasData ? "✓data" : "✗data")
        }
        return results.joined(separator: "\n")
    }

    // MARK: - SCATTER write helpers

    private func scatterWrite(_ data: Data, forKey key: String) {
        // 1. Write to every app-group UserDefaults suite we can reach
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) {
                ud.set(data, forKey: key)
                ud.synchronize()
            }
        }
        // 2. Write to every app-group container file
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                try? data.write(to: url, options: .atomicWrite)
            }
        }
        // 3. Standard UserDefaults as last resort (not shared with extension)
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.synchronize()
    }

    // MARK: - GATHER read helper

    private func gatherRead(forKey key: String) -> Data? {
        // 1. Try every app-group UserDefaults suite
        for id in Self.appGroupCandidates {
            if let data = UserDefaults(suiteName: id)?.data(forKey: key), !data.isEmpty {
                return data
            }
        }
        // 2. Try every app-group container file
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                if let data = try? Data(contentsOf: url), !data.isEmpty {
                    return data
                }
            }
        }
        // 3. Standard UserDefaults
        return UserDefaults.standard.data(forKey: key)
    }

    // MARK: - Configuration CRUD

    func saveConfigurations(_ configurations: [WidgetConfig]) throws {
        let data = try encoder.encode(configurations)
        scatterWrite(data, forKey: Self.configKey)
        appendExtensionLog("SAVE: \(configurations.count) configs written to all groups")
    }

    func loadConfigurations() throws -> [WidgetConfig] {
        guard let data = gatherRead(forKey: Self.configKey) else {
            appendExtensionLog("LOAD: no data found in any group")
            return []
        }
        let configs = try decoder.decode([WidgetConfig].self, from: data)
        appendExtensionLog("LOAD: \(configs.count) configs from group")
        return configs
    }

    func getConfig(id: String) -> WidgetConfig? {
        (try? loadConfigurations())?.first { $0.id.uuidString == id }
    }

    func getConfig(named name: String) -> WidgetConfig? {
        (try? loadConfigurations())?.first { $0.name == name }
    }

    func deleteAllConfigurations() throws {
        for id in Self.appGroupCandidates {
            UserDefaults(suiteName: id)?.removeObject(forKey: Self.configKey)
            UserDefaults(suiteName: id)?.synchronize()
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                try? FileManager.default.removeItem(
                    at: container.appendingPathComponent("widgetConfigs.json"))
            }
        }
        UserDefaults.standard.removeObject(forKey: Self.configKey)
    }

    // MARK: - Extension Debug Log
    // Written by BOTH the main app and the extension to all groups.
    // The main app reads it back in DebugOverlayView to diagnose issues.

    func appendExtensionLog(_ message: String) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let line = "[\(iso.string(from: Date()))] \(message)"

        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) {
                let existing = ud.string(forKey: Self.extensionLogKey) ?? ""
                let lines = existing.components(separatedBy: "\n").filter { !$0.isEmpty }
                let trimmed = Array(lines.suffix(30)) + [line]
                ud.set(trimmed.joined(separator: "\n"), forKey: Self.extensionLogKey)
                ud.synchronize()
            }
        }
        let existing = UserDefaults.standard.string(forKey: Self.extensionLogKey) ?? ""
        let lines = existing.components(separatedBy: "\n").filter { !$0.isEmpty }
        UserDefaults.standard.set(
            (Array(lines.suffix(30)) + [line]).joined(separator: "\n"),
            forKey: Self.extensionLogKey)
    }

    func readExtensionLog() -> String {
        for id in Self.appGroupCandidates {
            if let log = UserDefaults(suiteName: id)?.string(forKey: Self.extensionLogKey),
               !log.isEmpty {
                return log
            }
        }
        return UserDefaults.standard.string(forKey: Self.extensionLogKey)
            ?? "No extension log found"
    }

    func clearExtensionLog() {
        for id in Self.appGroupCandidates {
            UserDefaults(suiteName: id)?.removeObject(forKey: Self.extensionLogKey)
            UserDefaults(suiteName: id)?.synchronize()
        }
        UserDefaults.standard.removeObject(forKey: Self.extensionLogKey)
    }

    // MARK: - Backup / Restore

    /// Saves a backup JSON directly to the app's Documents directory root.
    /// Visible in Files.app as "On My iPhone / Widget / widget_backup.json".
    func createBackup() throws -> URL? {
        let configs = try loadConfigurations()
        guard !configs.isEmpty else { return nil }

        let json = try encoder.encode(configs)
        let docsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = docsURL.appendingPathComponent("widget_backup.json")
        try json.write(to: backupURL, options: .atomicWrite)
        lastBackupDate = Date()
        return backupURL
    }

    func restoreFromBackup() throws -> Bool {
        let docsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        let candidates = [
            docsURL.appendingPathComponent("widget_backup.json"),
            docsURL.appendingPathComponent("Start/widget_backup.json")
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
        return StorageInfo(appGroupID: activeAppGroupID,
                           configurationCount: configs.count,
                           size: configs.count)
    }

    // MARK: - Preferences (shared via scatter-gather so extension can read them)

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var lastBackupDate: Date? {
        get {
            for id in Self.appGroupCandidates {
                if let d = UserDefaults(suiteName: id)?.object(forKey: "lastBackupDate") as? Date {
                    return d
                }
            }
            return nil
        }
        set {
            for id in Self.appGroupCandidates {
                UserDefaults(suiteName: id)?.set(newValue, forKey: "lastBackupDate")
                UserDefaults(suiteName: id)?.synchronize()
            }
        }
    }

    var showItemLabels: Bool {
        get {
            for id in Self.appGroupCandidates {
                if let val = UserDefaults(suiteName: id)?.object(forKey: "showItemLabels") as? Bool {
                    return val
                }
            }
            return true
        }
        set {
            for id in Self.appGroupCandidates {
                UserDefaults(suiteName: id)?.set(newValue, forKey: "showItemLabels")
                UserDefaults(suiteName: id)?.synchronize()
            }
        }
    }

    var hapticFeedback: Bool {
        get {
            for id in Self.appGroupCandidates {
                if let val = UserDefaults(suiteName: id)?.object(forKey: "hapticFeedback") as? Bool {
                    return val
                }
            }
            return true
        }
        set {
            for id in Self.appGroupCandidates {
                UserDefaults(suiteName: id)?.set(newValue, forKey: "hapticFeedback")
                UserDefaults(suiteName: id)?.synchronize()
            }
        }
    }
}

// MARK: - Supporting Types

struct StorageInfo {
    let appGroupID: String
    let configurationCount: Int
    let size: Int
}

enum StorageError: Error { case noDefaults }

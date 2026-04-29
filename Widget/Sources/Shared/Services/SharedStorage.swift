import Foundation
import Security

/// Shared persistent storage used by both the main app and the widget extension.
///
/// Storage priority (write ALL, read in order):
///   1. Shared Keychain access group — the ONLY mechanism that genuinely crosses
///      the process boundary on SideStore/AltStore free accounts. Both targets
///      declare `$(AppIdentifierPrefix)com.iosmirror.shared`; SideStore transforms
///      `$(AppIdentifierPrefix)` → `J3D2F4SMVD.` for both, giving both processes
///      the same `J3D2F4SMVD.com.iosmirror.shared` group.
///   2. App-group UserDefaults (scatter-gather across all three candidate IDs).
///   3. App-group container files.
///   4. Standard UserDefaults (process-local last resort).
final class SharedStorage {

    static let shared = SharedStorage()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Constants

    static let configKey        = "widgetConfigurations"
    static let extensionLogKey  = "widgetExtensionLog"

    /// All app-group candidates, in priority order.
    static let appGroupCandidates: [String] = [
        "group.com.iosmirror.J3D2F4SMVD",   // SideStore: team ID appended
        "group.J3D2F4SMVD.com.iosmirror",   // SideStore: team ID prepended
        "group.com.iosmirror"                // canonical / unsigned
    ]

    // MARK: - Keychain shared access group

    /// The keychain access group shared between the main app and widget extension.
    ///
    /// The entitlement declares `$(AppIdentifierPrefix)com.iosmirror.shared`.
    /// SideStore (team ID J3D2F4SMVD) expands `$(AppIdentifierPrefix)` →
    /// `J3D2F4SMVD.` for both targets, so both processes reach the same group.
    /// `SecTaskCreateFromSelf` is macOS-only; we detect the active group at
    /// runtime by probing each candidate with a harmless read.
    static let sharedKeychainGroup: String? = {
        let candidates = [
            "J3D2F4SMVD.com.iosmirror.shared",  // SideStore / AltStore (team J3D2F4SMVD)
            "com.iosmirror.shared"               // unsigned / simulator
        ]
        for group in candidates {
            let query: [String: Any] = [
                kSecClass as String:           kSecClassGenericPassword,
                kSecAttrService as String:     "com.iosmirror.widgetdata",
                kSecAttrAccount as String:     "__groupprobe__",
                kSecAttrAccessGroup as String: group,
                kSecReturnData as String:      false,
                kSecMatchLimit as String:      kSecMatchLimitOne
            ]
            let status = SecItemCopyMatching(query as CFDictionary, nil)
            // errSecItemNotFound means the group is accessible but item absent — group works
            // errSecSuccess means a probe item exists — group works
            if status == errSecItemNotFound || status == errSecSuccess {
                return group
            }
        }
        // Fall back to first candidate; Keychain calls will fail gracefully if wrong
        return candidates.first
    }()

    private static let keychainService = "com.iosmirror.widgetdata"

    // MARK: - Init

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Keychain helpers

    private func keychainWrite(_ data: Data, forKey key: String) {
        guard let group = Self.sharedKeychainGroup else { return }
        var query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: group
        ]
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String]    = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainRead(forKey key: String) -> Data? {
        guard let group = Self.sharedKeychainGroup else { return nil }
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrService as String:     Self.keychainService,
            kSecAttrAccount as String:     key,
            kSecAttrAccessGroup as String: group,
            kSecReturnData as String:      true,
            kSecMatchLimit as String:      kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    /// True when the shared Keychain already contains widget config data.
    var keychainHasConfigs: Bool {
        guard let group = Self.sharedKeychainGroup else { return false }
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrService as String:     Self.keychainService,
            kSecAttrAccount as String:     Self.configKey,
            kSecAttrAccessGroup as String: group,
            kSecReturnData as String:      false,
            kSecMatchLimit as String:      kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private func keychainDelete(forKey key: String) {
        guard let group = Self.sharedKeychainGroup else { return }
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrService as String:     Self.keychainService,
            kSecAttrAccount as String:     key,
            kSecAttrAccessGroup as String: group
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Accessors (for UI display)

    var activeAppGroupID: String {
        if keychainRead(forKey: Self.configKey) != nil { return "keychain:\(Self.sharedKeychainGroup ?? "nil")" }
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

    var groupDiagnostic: String {
        let kcGroup = Self.sharedKeychainGroup ?? "nil"
        let kcData  = keychainRead(forKey: Self.configKey) != nil
        var lines = ["keychain:\(kcGroup): " + (kcData ? "✓data" : "✗data")]
        lines += Self.appGroupCandidates.map { id -> String in
            let hasContainer = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) != nil
            let hasData = UserDefaults(suiteName: id)?.data(forKey: Self.configKey) != nil
            return "\(id.replacingOccurrences(of: "group.", with: "")): "
                + (hasContainer ? "✓container" : "✗container")
                + " " + (hasData ? "✓data" : "✗data")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - SCATTER write helpers

    private func scatterWrite(_ data: Data, forKey key: String) {
        // 1. Keychain (primary cross-process channel)
        keychainWrite(data, forKey: key)
        // 2. App-group UserDefaults suites
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) {
                ud.set(data, forKey: key)
                ud.synchronize()
            }
        }
        // 3. App-group container files
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                try? data.write(to: url, options: .atomicWrite)
            }
        }
        // 4. Standard UserDefaults (process-local last resort)
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.synchronize()
    }

    // MARK: - GATHER read helper

    private func gatherRead(forKey key: String) -> Data? {
        // 1. Keychain (primary cross-process channel)
        if let data = keychainRead(forKey: key), !data.isEmpty { return data }
        // 2. App-group UserDefaults suites
        for id in Self.appGroupCandidates {
            if let data = UserDefaults(suiteName: id)?.data(forKey: key), !data.isEmpty {
                return data
            }
        }
        // 3. App-group container files
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                if let data = try? Data(contentsOf: url), !data.isEmpty {
                    return data
                }
            }
        }
        // 4. Standard UserDefaults
        return UserDefaults.standard.data(forKey: key)
    }

    // MARK: - Configuration CRUD

    func saveConfigurations(_ configurations: [WidgetConfig]) throws {
        let data = try encoder.encode(configurations)
        scatterWrite(data, forKey: Self.configKey)
        let kcOK = keychainRead(forKey: Self.configKey) != nil
        appendExtensionLog("SAVE: \(configurations.count) configs written (kc:\(kcOK ? "ok" : "fail"))")
    }

    func loadConfigurations() throws -> [WidgetConfig] {
        guard let data = gatherRead(forKey: Self.configKey) else {
            appendExtensionLog("LOAD: no data found in any store")
            return []
        }
        let configs = try decoder.decode([WidgetConfig].self, from: data)
        appendExtensionLog("LOAD: \(configs.count) configs")
        return configs
    }

    func getConfig(id: String) -> WidgetConfig? {
        (try? loadConfigurations())?.first { $0.id.uuidString == id }
    }

    func getConfig(named name: String) -> WidgetConfig? {
        (try? loadConfigurations())?.first { $0.name == name }
    }

    func deleteAllConfigurations() throws {
        keychainDelete(forKey: Self.configKey)
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

    func appendExtensionLog(_ message: String) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let line = "[\(iso.string(from: Date()))] \(message)"

        // Write log to keychain
        let existing = keychainRead(forKey: Self.extensionLogKey)
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let lines = existing.components(separatedBy: "\n").filter { !$0.isEmpty }
        let updated = (Array(lines.suffix(30)) + [line]).joined(separator: "\n")
        if let data = updated.data(using: .utf8) {
            keychainWrite(data, forKey: Self.extensionLogKey)
        }

        // Also write to all UserDefaults
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) {
                let ex = ud.string(forKey: Self.extensionLogKey) ?? ""
                let ls = ex.components(separatedBy: "\n").filter { !$0.isEmpty }
                ud.set((Array(ls.suffix(30)) + [line]).joined(separator: "\n"),
                       forKey: Self.extensionLogKey)
                ud.synchronize()
            }
        }
        let ex = UserDefaults.standard.string(forKey: Self.extensionLogKey) ?? ""
        let ls = ex.components(separatedBy: "\n").filter { !$0.isEmpty }
        UserDefaults.standard.set(
            (Array(ls.suffix(30)) + [line]).joined(separator: "\n"),
            forKey: Self.extensionLogKey)
    }

    func readExtensionLog() -> String {
        // Try Keychain first
        if let data = keychainRead(forKey: Self.extensionLogKey),
           let log = String(data: data, encoding: .utf8), !log.isEmpty {
            return log
        }
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
        keychainDelete(forKey: Self.extensionLogKey)
        for id in Self.appGroupCandidates {
            UserDefaults(suiteName: id)?.removeObject(forKey: Self.extensionLogKey)
            UserDefaults(suiteName: id)?.synchronize()
        }
        UserDefaults.standard.removeObject(forKey: Self.extensionLogKey)
    }

    // MARK: - Backup / Restore

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

    // MARK: - Preferences

    private func keychainBool(forKey key: String) -> Bool? {
        guard let data = keychainRead(forKey: key),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str == "true"
    }

    private func setKeychainBool(_ value: Bool, forKey key: String) {
        let str = value ? "true" : "false"
        if let data = str.data(using: .utf8) { keychainWrite(data, forKey: key) }
    }

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
            // Keychain first (cross-process)
            if let val = keychainBool(forKey: "showItemLabels") { return val }
            for id in Self.appGroupCandidates {
                if let val = UserDefaults(suiteName: id)?.object(forKey: "showItemLabels") as? Bool {
                    return val
                }
            }
            return true
        }
        set {
            setKeychainBool(newValue, forKey: "showItemLabels")
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

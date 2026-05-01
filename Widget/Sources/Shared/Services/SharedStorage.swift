import Foundation
import Security
#if canImport(UIKit)
import UIKit
#endif

/// Shared persistent storage used by both the main app and the widget extension.
///
/// Storage priority (write ALL, read in order):
///   1. Shared Keychain access group — the ONLY mechanism that genuinely crosses
///      the process boundary on SideStore/AltStore free accounts. Both targets
///      declare `$(AppIdentifierPrefix)com.ioswidget.shared`; SideStore transforms
///      `$(AppIdentifierPrefix)` → `J3D2F4SMVD.` for both, giving both processes
///      the same `J3D2F4SMVD.com.ioswidget.shared` group.
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
        "group.com.ioswidget.J3D2F4SMVD",   // SideStore: team ID appended
        "group.J3D2F4SMVD.com.ioswidget",   // SideStore: team ID prepended
        "group.com.ioswidget"                // canonical / unsigned
    ]

    // MARK: - Keychain shared access group

    /// The keychain access group shared between the main app and widget extension.
    ///
    /// The entitlement hardcodes `J3D2F4SMVD.com.ioswidget.shared` (no variable
    /// expansion needed). SideStore leaves already-prefixed team-ID groups alone.
    /// We probe at runtime so the fallback (`com.ioswidget.shared`) covers the
    /// simulator / unsigned builds. `SecTaskCreateFromSelf` is macOS-only, so we
    /// use a harmless SecItemCopyMatching probe instead.
    /// Non-nil only when a test write to the group actually succeeds (errSecSuccess).
    /// A read-only probe returns errSecItemNotFound even without the entitlement on
    /// some iOS versions, so we must probe with a write to get a reliable answer.
    static let sharedKeychainGroup: String? = {
        let candidates = [
            "J3D2F4SMVD.com.ioswidget.shared",
            "com.ioswidget.shared"
        ]
        for group in candidates {
            var q: [String: Any] = [
                kSecClass as String:           kSecClassGenericPassword,
                kSecAttrService as String:     "com.ioswidget.widgetdata",
                kSecAttrAccount as String:     "__writeprobe__",
                kSecAttrAccessGroup as String: group
            ]
            SecItemDelete(q as CFDictionary)
            q[kSecValueData as String]      = Data([0x01])
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let status = SecItemAdd(q as CFDictionary, nil)
            if status == errSecSuccess {
                SecItemDelete(q as CFDictionary)
                return group
            }
        }
        return nil  // nil = keychain sharing unavailable (e.g. SideStore strips the entitlement)
    }()

    private static let keychainService = "com.ioswidget.widgetdata"

    // MARK: - Init

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Keychain helpers

    @discardableResult
    private func keychainWrite(_ data: Data, forKey key: String) -> OSStatus {
        guard let group = Self.sharedKeychainGroup else { return errSecMissingEntitlement }
        var query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrService as String:     Self.keychainService,
            kSecAttrAccount as String:     key,
            kSecAttrAccessGroup as String: group
        ]
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String]      = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Log write failure directly to standard UserDefaults (no recursion risk)
            let msg = "KC-WRITE-FAIL key=\(key) group=\(group) status=\(status)"
            let existing = UserDefaults.standard.string(forKey: Self.extensionLogKey) ?? ""
            let lines = existing.components(separatedBy: "\n").filter { !$0.isEmpty }
            UserDefaults.standard.set(
                (Array(lines.suffix(30)) + [msg]).joined(separator: "\n"),
                forKey: Self.extensionLogKey)
        }
        return status
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

        // Live write test: write a tiny probe item and read it back, then delete.
        // This tells us definitively if cross-process keychain is functional.
        let writeTestStatus: String
        if let group = Self.sharedKeychainGroup {
            let probe = "probe".data(using: .utf8)!
            var wq: [String: Any] = [
                kSecClass as String:           kSecClassGenericPassword,
                kSecAttrService as String:     Self.keychainService,
                kSecAttrAccount as String:     "__diagprobe__",
                kSecAttrAccessGroup as String: group
            ]
            SecItemDelete(wq as CFDictionary)
            wq[kSecValueData as String]      = probe
            wq[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addSt = SecItemAdd(wq as CFDictionary, nil)
            if addSt == errSecSuccess {
                // Try reading back immediately
                var rq = wq; rq[kSecReturnData as String] = true; rq[kSecMatchLimit as String] = kSecMatchLimitOne
                rq.removeValue(forKey: kSecValueData as String); rq.removeValue(forKey: kSecAttrAccessible as String)
                var ref: AnyObject?
                let rdSt = SecItemCopyMatching(rq as CFDictionary, &ref)
                SecItemDelete(wq as CFDictionary)
                writeTestStatus = rdSt == errSecSuccess ? "write✓read✓" : "write✓read✗(\(rdSt))"
            } else {
                writeTestStatus = "write✗(\(addSt))"
            }
        } else {
            writeTestStatus = "no-group"
        }

        var lines = ["keychain:\(kcGroup): " + (kcData ? "✓data" : "✗data") + " test:\(writeTestStatus)"]
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
        let kcStatus = keychainWrite(data, forKey: key)
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
        let kcWriteStatus = keychainWrite(data, forKey: Self.configKey)
        // Also scatter to UserDefaults/files as fallback
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) { ud.set(data, forKey: Self.configKey); ud.synchronize() }
        }
        UserDefaults.standard.set(data, forKey: Self.configKey)
        UserDefaults.standard.synchronize()
        appendExtensionLog("SAVE: \(configurations.count) configs kc=\(kcWriteStatus==errSecSuccess ? "ok" : "fail(\(kcWriteStatus))")")
    }

    func loadConfigurations() throws -> [WidgetConfig] {
        guard let data = gatherRead(forKey: Self.configKey) else {
            appendExtensionLog("LOAD: no data found in any store")
            return []
        }
        var configs = try decoder.decode([WidgetConfig].self, from: data)
        // Populate imageData for every slide from the image store (imageData is not serialized
        // to keep JSON small; SharedStorage holds the authoritative copy).
        for i in configs.indices {
            guard configs[i].slides != nil else { continue }
            for j in configs[i].slides!.indices {
                let fn = configs[i].slides![j].filename
                // Storage takes priority; if unavailable (cross-process) keep data from JSON
                if let d = loadWidgetImageData(filename: fn) {
                    configs[i].slides![j].imageData = d
                }
            }
        }
        if !configs.isEmpty && keychainRead(forKey: Self.configKey) == nil {
            let st = keychainWrite(data, forKey: Self.configKey)
            appendExtensionLog("LOAD: migrated \(configs.count) configs → kc=\(st==errSecSuccess ? "ok" : "fail(\(st))")")
        } else {
            appendExtensionLog("LOAD: \(configs.count) configs")
        }
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

    // MARK: - Widget Image Storage

    /// Directory where widget slide images are stored.
    /// Tries app group container first (accessible by both targets), falls back to Documents.
    func widgetImagesDirectory() -> URL {
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let dir = container.appendingPathComponent("widget_images")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            }
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("widget_images")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveWidgetImage(_ data: Data, filename: String) {
        let udKey = "wi_\(filename)"
        // 0. Keychain (cross-process on devices where entitlement works)
        keychainWrite(data, forKey: udKey)
        // 1. App-group containers
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let dir = container.appendingPathComponent("widget_images")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try? data.write(to: dir.appendingPathComponent(filename), options: .atomicWrite)
            }
        }
        // 2. Documents directory (always accessible in the main app process)
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("widget_images")
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)
        try? data.write(to: docDir.appendingPathComponent(filename), options: .atomicWrite)
        // 3. App-group UserDefaults
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) { ud.set(data, forKey: udKey); ud.synchronize() }
        }
        // 4. Standard UserDefaults — always works within the same process (main app preview)
        UserDefaults.standard.set(data, forKey: udKey)
        UserDefaults.standard.synchronize()
    }

    /// Load raw JPEG bytes for a slide image (used to populate imageData after deserialization).
    func loadWidgetImageData(filename: String) -> Data? {
        let udKey = "wi_\(filename)"
        if let d = keychainRead(forKey: udKey), !d.isEmpty { return d }
        for id in Self.appGroupCandidates {
            if let c = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                let url = c.appendingPathComponent("widget_images").appendingPathComponent(filename)
                if let d = try? Data(contentsOf: url), !d.isEmpty { return d }
            }
        }
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("widget_images").appendingPathComponent(filename)
        if let d = try? Data(contentsOf: docURL), !d.isEmpty { return d }
        for id in Self.appGroupCandidates {
            if let d = UserDefaults(suiteName: id)?.data(forKey: udKey), !d.isEmpty { return d }
        }
        // Standard UserDefaults — always readable in same process
        if let d = UserDefaults.standard.data(forKey: udKey), !d.isEmpty { return d }
        return nil
    }

    #if canImport(UIKit)
    func loadWidgetImage(filename: String) -> UIImage? {
        loadWidgetImageData(filename: filename).flatMap { UIImage(data: $0) }
    }
    #endif

    func deleteWidgetImage(filename: String) {
        keychainDelete(forKey: "wi_\(filename)")
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                try? FileManager.default.removeItem(
                    at: container.appendingPathComponent("widget_images")
                        .appendingPathComponent(filename))
            }
        }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("widget_images").appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        let udKey = "wi_\(filename)"
        for id in Self.appGroupCandidates {
            UserDefaults(suiteName: id)?.removeObject(forKey: udKey)
            UserDefaults(suiteName: id)?.synchronize()
        }
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

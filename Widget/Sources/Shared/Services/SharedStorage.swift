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

    static let sharedKeychainGroup: String? = {
        // Discover the actual team ID at runtime. On SideStore the signing team ID
        // may differ from the hardcoded "J3D2F4SMVD", so we write a probe item
        // without specifying an access group, read back the kSecAttrAccessGroup
        // attribute iOS assigned, and extract the team-ID prefix from it.
        var discoveredCandidate: String? = nil
        let discSvc = "com.ioswidget.teamdiscover"
        let discAcc = "__teamdiscover__"
        var dq: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                  kSecAttrService as String: discSvc,
                                  kSecAttrAccount as String: discAcc]
        SecItemDelete(dq as CFDictionary)
        var aq = dq
        aq[kSecValueData as String]      = Data([0x01])
        aq[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(aq as CFDictionary, nil) == errSecSuccess {
            var rq = dq
            rq[kSecReturnAttributes as String] = true
            rq[kSecMatchLimit as String]        = kSecMatchLimitOne
            var out: AnyObject?
            if SecItemCopyMatching(rq as CFDictionary, &out) == errSecSuccess,
               let attrs  = out as? [String: Any],
               let grp    = attrs[kSecAttrAccessGroup as String] as? String {
                // grp looks like "TEAMID.com.ioswidget[.extension]"
                // Team IDs are always 10 uppercase alphanumeric chars.
                let prefix = grp.split(separator: ".").first.map(String.init) ?? ""
                if prefix.count >= 8 {
                    discoveredCandidate = "\(prefix).com.ioswidget.shared"
                }
            }
            SecItemDelete(dq as CFDictionary)
        }

        // Probe candidates: dynamic discovery first, then hardcoded fallbacks.
        var seen = Set<String>()
        let candidates = ([discoveredCandidate, "J3D2F4SMVD.com.ioswidget.shared",
                           "com.ioswidget.shared"] as [String?])
            .compactMap { $0 }
            .filter { seen.insert($0).inserted }

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
        return nil
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
    /// Returns which storage location is currently active for configs.
    /// Checks UserDefaults.standard first (shared for unsandboxed apps), then keychain, then App Groups.
    func getActiveStorageName() -> String {
        // First check UserDefaults.standard (shared for unsandboxed apps)
        let standardData = UserDefaults.standard.data(forKey: Self.configKey)
        if standardData != nil, !standardData!.isEmpty {
            return "standard(\(standardData!.count)bytes)"
        }
        // Keychain has data
        if let kcData = keychainRead(forKey: Self.configKey), !kcData.isEmpty {
            return "kc:" + (Self.sharedKeychainGroup ?? "nil")
        }
        // Check each App Group candidate
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id), let data = ud.data(forKey: Self.configKey), !data.isEmpty {
                return id.replacingOccurrences(of: "group.", with: "")
            }
        }
        // Debug: check if key exists with different data
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let matchingKeys = allKeys.filter { $0.contains("WidgetConfig") || $0.contains("config") }
        if !matchingKeys.isEmpty {
            return "NONE(keyMatch:\(matchingKeys.first ?? "?"))"
        }
        return "NONE"
    }


    // MARK: - SCATTER write helpers

    private func scatterWrite(_ data: Data, forKey key: String) {
        keychainWrite(data, forKey: key)
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) {
                ud.set(data, forKey: key)
                ud.synchronize()
            }
        }
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                try? data.write(to: url, options: .atomicWrite)
            }
        }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.synchronize()
    }

    // MARK: - Lightweight string override (used by SwapWidgetItemsIntent for itemOrder)

    func scatterWriteOverride(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        keychainWrite(data, forKey: key)
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) {
                ud.set(value, forKey: key)
                ud.synchronize()
            }
        }
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("\(key).dat")
                try? data.write(to: url, options: .atomicWrite)
            }
        }
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }

    func gatherReadOverride(forKey key: String) -> String? {
        if let data = keychainRead(forKey: key),
           let s = String(data: data, encoding: .utf8), !s.isEmpty { return s }
        for id in Self.appGroupCandidates {
            if let s = UserDefaults(suiteName: id)?.string(forKey: key), !s.isEmpty { return s }
        }
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("\(key).dat")
                if let data = try? Data(contentsOf: url),
                   let s = String(data: data, encoding: .utf8), !s.isEmpty { return s }
            }
        }
        if let s = UserDefaults.standard.string(forKey: key), !s.isEmpty { return s }
        return nil
    }

    // MARK: - GATHER read helper

    private func gatherRead(forKey key: String) -> Data? {
        // First check UserDefaults.standard - this is shared for unsandboxed apps
        if let data = UserDefaults.standard.data(forKey: key), !data.isEmpty {
            return data
        }
        if let data = keychainRead(forKey: key), !data.isEmpty { return data }
        for id in Self.appGroupCandidates {
            if let data = UserDefaults(suiteName: id)?.data(forKey: key), !data.isEmpty {
                return data
            }
        }
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                if let data = try? Data(contentsOf: url), !data.isEmpty {
                    return data
                }
            }
        }
        return nil
    }
    
    /// Debug version that returns both data and source info
    func gatherReadDebug(forKey key: String) -> (data: Data?, source: String) {
        // First check UserDefaults.standard
        if let data = UserDefaults.standard.data(forKey: key), !data.isEmpty {
            return (data, "UserDefaults.standard(\(data.count)bytes)")
        }
        if let data = keychainRead(forKey: key), !data.isEmpty { 
            return (data, "keychain")
        }
        for id in Self.appGroupCandidates {
            if let data = UserDefaults(suiteName: id)?.data(forKey: key), !data.isEmpty {
                return (data, "AppGroup(\(id))")
            }
        }
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                if let data = try? Data(contentsOf: url), !data.isEmpty {
                    return (data, "file(\(id))")
                }
            }
        }
        return (nil, "NOT FOUND")
    }
    
    /// Returns where gatherRead would find data and the source
    func debugReadSource(forKey key: String) -> String {
        return gatherReadDebug(forKey: key).source
    }


    /// Write debug info about gatherRead to a shared file (for debugging)
    func writeWidgetDebugInfo() {
        let result = gatherReadDebug(forKey: Self.configKey)
        var info = "Widget Extension Debug Info
"
        info += "gatherReadDebug result: \(result.source)
"
        info += "data size: \(result.data?.count ?? -1)
"
        
        // Check each source directly
        let standardData = UserDefaults.standard.data(forKey: Self.configKey)
        info += "UserDefaults.standard: \(standardData?.count ?? -1) bytes
"
        
        for id in Self.appGroupCandidates {
            let ud = UserDefaults(suiteName: id)
            let data = ud?.data(forKey: Self.configKey)
            info += "AppGroup(\(id)): \(data?.count ?? -1) bytes
"
        }
        
        // Check shared container files
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                if let data = try? Data(contentsOf: url) {
                    info += "File(\(id)): \(data.count) bytes
"
                }
            }
        }
        
        // Check all UserDefaults.standard keys
        info += "
All UserDefaults.standard keys containing 'config' or 'Widget':
"
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys {
            if key.lowercased().contains("config") || key.lowercased().contains("widget") {
                if let data = UserDefaults.standard.data(forKey: key) {
                    info += "  \(key): \(data.count) bytes
"
                }
            }
        }
        
        // Write to first available shared container
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widget_debug.txt")
                try? info.write(to: url, atomically: true, encoding: .utf8)
                return
            }
        }
        
        // Last resort: write to documents directory
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent("widget_debug.txt")
            try? info.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Configuration CRUD

    func saveConfigurations(_ configurations: [WidgetConfig]) throws {
        var compact = configurations
        for i in compact.indices {
            for j in (compact[i].slides ?? []).indices {
                compact[i].slides![j].imageData = nil
            }
            for j in compact[i].items.indices {
                compact[i].items[j].imageData = nil
            }
        }
        let data = try encoder.encode(compact)
        let kcWriteStatus = keychainWrite(data, forKey: Self.configKey)
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) { ud.set(data, forKey: Self.configKey); ud.synchronize() }
        }
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                try? data.write(to: url, options: .atomicWrite)
            }
        }
        UserDefaults.standard.set(data, forKey: Self.configKey)
        UserDefaults.standard.synchronize()
        appendExtensionLog("SAVE: \(configurations.count) configs size=\(data.count) kc=\(kcWriteStatus==errSecSuccess ? "ok" : "fail(\(kcWriteStatus))")")    }

    func loadConfigurations() throws -> [WidgetConfig] {
        // Debug: log what gatherRead finds
        let readResult = gatherReadDebug(forKey: Self.configKey)
        appendExtensionLog("LOAD: gatherRead returned source=\(readResult.source), data=\(readResult.data?.count ?? -1)")
        
        guard let data = readResult.data else {
            appendExtensionLog("LOAD: no data found in any store")
            return []
        }
        var configs = try decoder.decode([WidgetConfig].self, from: data)
        for i in configs.indices {
            if configs[i].slides != nil {
                for j in configs[i].slides!.indices {
                    let fn = configs[i].slides![j].filename
                    guard !fn.isEmpty else { continue }
                    if let d = loadWidgetImageData(filename: fn) {
                        configs[i].slides![j].imageData = d
                    }
                }
            }
            for j in configs[i].items.indices {
                guard configs[i].items[j].displayType == .image,
                      let fn = configs[i].items[j].customImageFilename,
                      !fn.isEmpty else { continue }
                if let d = loadWidgetImageData(filename: fn) {
                    configs[i].items[j].imageData = d
                }
            }
        }
        if !configs.isEmpty && keychainRead(forKey: Self.configKey) == nil {
            let st = keychainWrite(data, forKey: Self.configKey)
            appendExtensionLog("LOAD: migrated \(configs.count) configs → kc=\(st==errSecSuccess ? "ok" : "fail(\(st))")")        } else {
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

        let existing = keychainRead(forKey: Self.extensionLogKey)
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let lines = existing.components(separatedBy: "\n").filter { !$0.isEmpty }
        let updated = (Array(lines.suffix(30)) + [line]).joined(separator: "\n")
        if let data = updated.data(using: .utf8) {
            keychainWrite(data, forKey: Self.extensionLogKey)
        }

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
        for id in Self.appGroupCandidates {
            if let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: id) {
                let dir = container.appendingPathComponent("widget_images")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try? data.write(to: dir.appendingPathComponent(filename), options: .atomicWrite)
            }
        }
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("widget_images")
        try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true)
        try? data.write(to: docDir.appendingPathComponent(filename), options: .atomicWrite)
    }

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

    struct CombinedBackup: Codable {
        var widgetConfigs: [WidgetConfig]
        var launcherConfigs: [LauncherConfig]?
    }

    func createBackup() throws -> URL? {
        let widgetConfigs   = try loadConfigurations()
        let launcherConfigs = (try? loadLauncherConfigs()) ?? []
        guard !widgetConfigs.isEmpty || !launcherConfigs.isEmpty else { return nil }

        let payload = CombinedBackup(widgetConfigs: widgetConfigs, launcherConfigs: launcherConfigs)
        let json = try encoder.encode(payload)
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = docsURL.appendingPathComponent("widget_backup.json")
        try json.write(to: backupURL, options: .atomicWrite)
        lastBackupDate = Date()
        return backupURL
    }

    @discardableResult
    func restoreFromBackup() throws -> Bool {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let candidates = [
            docsURL.appendingPathComponent("widget_backup.json"),
            docsURL.appendingPathComponent("Start/widget_backup.json")
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            try restoreBackupData(data)
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

    func createAutoBackup() throws {
        let widgetConfigs   = try loadConfigurations()
        let launcherConfigs = (try? loadLauncherConfigs()) ?? []
        guard !widgetConfigs.isEmpty || !launcherConfigs.isEmpty else { return }

        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupDir = docsURL.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let filename = "widget_backup_\(formatter.string(from: Date())).json"
        let backupURL = backupDir.appendingPathComponent(filename)
        guard !FileManager.default.fileExists(atPath: backupURL.path) else { return }

        let payload = CombinedBackup(widgetConfigs: widgetConfigs, launcherConfigs: launcherConfigs)
        let json = try encoder.encode(payload)
        try json.write(to: backupURL, options: .atomicWrite)

        let existing = (try? listAutoBackups()) ?? []
        if existing.count > 5 {
            for old in existing.dropFirst(5) { try? FileManager.default.removeItem(at: old) }
        }
    }

    func listAutoBackups() throws -> [URL] {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupDir = docsURL.appendingPathComponent("Backups", isDirectory: true)
        guard FileManager.default.fileExists(atPath: backupDir.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: backupDir, includingPropertiesForKeys: [.creationDateKey])
        return files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("widget_backup_") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func restoreFromAutoBackup(url: URL) throws {
        let data = try Data(contentsOf: url)
        try restoreBackupData(data)
    }

    private func restoreBackupData(_ data: Data) throws {
        if let combined = try? decoder.decode(CombinedBackup.self, from: data) {
            try saveConfigurations(combined.widgetConfigs)
            if let launchers = combined.launcherConfigs {
                try saveLauncherConfigs(launchers)
            }
        } else {
            let configs = try decoder.decode([WidgetConfig].self, from: data)
            try saveConfigurations(configs)
        }
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

    // MARK: - Launcher Config Storage

    private static let launcherKey = "launcherConfigurations"

    func saveLauncherConfigs(_ configs: [LauncherConfig]) throws {
        let data = try encoder.encode(configs)
        keychainWrite(data, forKey: Self.launcherKey)
        for id in Self.appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) {
                ud.set(data, forKey: Self.launcherKey)
                ud.synchronize()
            }
        }
        UserDefaults.standard.set(data, forKey: Self.launcherKey)
        UserDefaults.standard.synchronize()
    }

    func loadLauncherConfigs() throws -> [LauncherConfig] {
        if let data = keychainRead(forKey: Self.launcherKey), !data.isEmpty {
            return (try? decoder.decode([LauncherConfig].self, from: data)) ?? []
        }
        for id in Self.appGroupCandidates {
            if let data = UserDefaults(suiteName: id)?.data(forKey: Self.launcherKey), !data.isEmpty {
                return (try? decoder.decode([LauncherConfig].self, from: data)) ?? []
            }
        }
        if let data = UserDefaults.standard.data(forKey: Self.launcherKey), !data.isEmpty {
            return (try? decoder.decode([LauncherConfig].self, from: data)) ?? []
        }
        return []
    }

    // MARK: - Launcher Settings

    var launcherFontSize: Double {
        get { UserDefaults.standard.object(forKey: "launcherFontSize") as? Double ?? 16.0 }
        set { UserDefaults.standard.set(newValue, forKey: "launcherFontSize") }
    }

    var launcherRowHeight: Double {
        get { UserDefaults.standard.object(forKey: "launcherRowHeight") as? Double ?? 44.0 }
        set { UserDefaults.standard.set(newValue, forKey: "launcherRowHeight") }
    }

    var backTapLauncherID: String? {
        get { UserDefaults.standard.string(forKey: "backTapLauncherID") }
        set { UserDefaults.standard.set(newValue, forKey: "backTapLauncherID") }
    }

    // MARK: - Push Command Storage

    private static let pushCommandKey = "pushCommandEntries"

    func savePushCommandEntries(_ entries: [PushCommandEntry]) {
        guard let data = try? encoder.encode(entries) else { return }
        scatterWrite(data, forKey: Self.pushCommandKey)
    }

    func loadPushCommandEntries() -> [PushCommandEntry] {
        guard let data = gatherRead(forKey: Self.pushCommandKey) else { return [] }
        return (try? decoder.decode([PushCommandEntry].self, from: data)) ?? []
    }

    // MARK: - Local Server Settings

    /// Wi-Fi SSID the server is allowed to run on. Empty string = server disabled.
    var allowedSSID: String {
        get { UserDefaults.standard.string(forKey: "target_wifi_ssid") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "target_wifi_ssid") }
    }

    /// TCP port for the local HTTP server (default 8080).
    var serverPort: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "target_server_port")
            return v == 0 ? 8080 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: "target_server_port") }
    }

    /// Command ID received while the app was backgrounded. AppDelegate drains this
    /// in applicationDidBecomeActive and executes the corresponding action in foreground.
    var pendingRemoteCommandID: String? {
        get { UserDefaults.standard.string(forKey: "pendingRemoteCommandID") }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: "pendingRemoteCommandID") }
            else { UserDefaults.standard.removeObject(forKey: "pendingRemoteCommandID") }
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

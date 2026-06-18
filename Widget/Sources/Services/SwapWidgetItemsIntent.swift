import AppIntents
import WidgetKit

// MARK: - Code Widget Entity (for AdvanceCodeSlideIntent)

struct CodeWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Code Widget")
    }
    static var defaultQuery = CodeWidgetQuery()

    var id: String      // UUID string of the WidgetConfig
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) { self.id = id; self.name = name }
}

struct CodeWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CodeWidgetEntity] {
        let configs = codeWidgetConfigs()
        return identifiers.compactMap { id in
            configs.first(where: { $0.id.uuidString == id })
                .map { CodeWidgetEntity(id: $0.id.uuidString, name: $0.name) }
        }
    }
    func suggestedEntities() async throws -> [CodeWidgetEntity] {
        let list = codeWidgetConfigs()
        guard !list.isEmpty else {
            return [CodeWidgetEntity(id: "none", name: "No Code Widgets saved")]
        }
        return list.map { CodeWidgetEntity(id: $0.id.uuidString, name: $0.name) }
    }
    func defaultResult() async -> CodeWidgetEntity? {
        codeWidgetConfigs().first.map { CodeWidgetEntity(id: $0.id.uuidString, name: $0.name) }
    }
    private func codeWidgetConfigs() -> [WidgetConfig] {
        ((try? SharedStorage.shared.loadConfigurations()) ?? [])
            .filter { $0.widgetKind == .imageSlideshow }
    }
}

// MARK: - Advance Code Slide Intent (Shortcuts action)

struct AdvanceCodeSlideIntent: AppIntent {
    static var title: LocalizedStringResource = "Advance Code Widget Slide"
    static var description = IntentDescription("Advances or reverses the current slide in a Code Widget.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Widget",
               description: "The Code Widget whose slide to advance.")
    var widget: CodeWidgetEntity

    @Parameter(title: "Forward",
               description: "Advance forward (true) or backward (false).",
               default: true)
    var forward: Bool

    init() { widget = CodeWidgetEntity(id: "none", name: ""); forward = true }
    init(widget: CodeWidgetEntity, forward: Bool) {
        self.widget = widget; self.forward = forward
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard widget.id != "none" else {
            return .result(dialog: "No code widgets found. Create one in the app first.")
        }

        var configs = (try? SharedStorage.shared.loadConfigurations()) ?? []
        guard let idx = configs.firstIndex(where: { $0.id.uuidString == widget.id }) else {
            return .result(dialog: "Widget \"\(widget.name)\" not found. It may have been deleted.")
        }

        let slides = configs[idx].slides ?? []
        let count = slides.count
        guard count > 1 else {
            return .result(dialog: "\"\(widget.name)\" has only one slide — nothing to advance.")
        }

        let current = configs[idx].currentSlideIndex ?? 0
        let next = forward
            ? (current + 1) % count
            : (current - 1 + count) % count
        configs[idx].currentSlideIndex = next

        // Write lightweight slideIdx override to all cross-process stores (Int).
        let idxKey = "slideIdx_\(widget.id)"
        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.set(next, forKey: idxKey)
            UserDefaults(suiteName: id)?.synchronize()
        }
        UserDefaults.standard.set(next, forKey: idxKey)
        UserDefaults.standard.synchronize()

        try SharedStorage.shared.saveConfigurations(configs)

        // Post Darwin notification to reliably wake the widget extension process.
        // WidgetCenter.shared.reloadTimelines() may not work on sideloaded apps,
        // so we use Darwin notifications for guaranteed cross-process communication.
        DarwinNotificationCenter.shared.postSlideAdvance()

        WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastImage")

        let direction = forward ? "advanced to" : "reversed to"
        return .result(dialog: IntentDialog(stringLiteral:
            "\"\(widget.name)\": \(direction) slide \(next + 1) of \(count)."))
    }
}

// MARK: - Grid Widget Entity

struct GridWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Grid Widget")
    }
    static var defaultQuery = GridWidgetQuery()

    var id: String      // UUID string of the WidgetConfig
    var name: String
    var sizeLabel: String   // e.g. "Small 3×3" — shown as subtitle in picker

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(sizeLabel)"
        )
    }

    init(id: String, name: String, sizeLabel: String) {
        self.id = id; self.name = name; self.sizeLabel = sizeLabel
    }
}

// MARK: - Query

struct GridWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [GridWidgetEntity] {
        let configs = gridConfigs()
        return identifiers.compactMap { storedID in
            configs.first(where: { $0.id.uuidString == storedID })
                .map { GridWidgetEntity(id: $0.id.uuidString, name: $0.name, sizeLabel: $0.size.displayName) }
        }
    }

    func suggestedEntities() async throws -> [GridWidgetEntity] {
        let list = gridConfigs()
        guard !list.isEmpty else {
            return [GridWidgetEntity(id: "none", name: "No Grid Widgets saved", sizeLabel: "")]
        }
        return list.map { GridWidgetEntity(id: $0.id.uuidString, name: $0.name, sizeLabel: $0.size.displayName) }
    }

    func defaultResult() async -> GridWidgetEntity? {
        gridConfigs().first.map { GridWidgetEntity(id: $0.id.uuidString, name: $0.name, sizeLabel: $0.size.displayName) }
    }

    private func gridConfigs() -> [WidgetConfig] {
        ((try? SharedStorage.shared.loadConfigurations()) ?? [])
            .filter { $0.widgetKind == .grid || $0.widgetKind == nil }
            .filter { $0.size != .systemExtraLarge }
    }
}

// MARK: - Intent

struct SwapWidgetItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "Swap Widget Items"
    static var description = IntentDescription("Swaps two items in a Grid Widget by their positions. Position 1 is the top-left cell. Positions beyond the grid size (e.g. position 10 in a 3x3 widget) refer to pre-configured bench items. The widget updates when touched.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Widget",
               description: "The Grid Widget to modify.")
    var widget: GridWidgetEntity

    @Parameter(title: "Position A",
               description: "The first item position (1 = top-left, counts left-to-right, top-to-bottom). Can be a bench position beyond the grid size.",
               default: 1,
               inclusiveRange: (1, 72))
    var positionA: Int

    @Parameter(title: "Position B",
               description: "The second item position. Can be a bench position beyond the grid size.",
               default: 2,
               inclusiveRange: (1, 72))
    var positionB: Int

    init() {}
    init(widget: GridWidgetEntity, positionA: Int, positionB: Int) {
        self.widget = widget; self.positionA = positionA; self.positionB = positionB
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard widget.id != "none" else {
            return .result(dialog: IntentDialog(stringLiteral: "No grid widgets found"))
        }

        var configs = (try? SharedStorage.shared.loadConfigurations()) ?? []

        // Find the config - widget.id is already the UUID string
        guard let configIdx = configs.firstIndex(where: { $0.id.uuidString == widget.id }) else {
            return .result(dialog: IntentDialog(stringLiteral: "Widget \"\(widget.name)\" not found"))
        }

        let a = positionA - 1   // convert to 0-based
        let b = positionB - 1
        var config = configs[configIdx]
        let count = config.items.count

        guard a >= 0, a < count else {
            return .result(dialog: IntentDialog(stringLiteral: "Position \(positionA) out of range"))
        }
        guard b >= 0, b < count else {
            return .result(dialog: IntentDialog(stringLiteral: "Position \(positionB) out of range"))
        }
        guard a != b else {
            return .result(dialog: IntentDialog(stringLiteral: "Same positions - nothing to swap"))
        }

        let nameA = itemLabel(config.items[a])
        let nameB = itemLabel(config.items[b])

        config.items.swapAt(a, b)
        configs[configIdx] = config

        try SharedStorage.shared.saveConfigurations(configs)

        // Write item-order override using POSITION INDICES (not UUIDs)
        // Since SlimItem creates new UUIDs on load, we use array positions instead.
        // Format: "0,2,1,3,4" means position 0 stays at 0, position 1 moves to 2, etc.
        // NOTE: Use uppercase UUID to match makeEntry() which normalizes entityUUID.uppercased()
        let entityUUID = widget.id.uppercased()
        let orderKey = "itemOrder_\(entityUUID)"
        let orderValue = (0..<config.items.count).map(String.init).joined(separator: ",")
        SharedStorage.shared.scatterWriteOverride(orderValue, forKey: orderKey)

        // Write fresh config JSON to UserDefaults.standard (same as RefreshWidgetIntent)
        let freshConfigKey = "freshConfig_\(entityUUID)"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let configData = try? encoder.encode(config) {
            let configJSON = configData.base64EncodedString()
            UserDefaults.standard.set(configJSON, forKey: freshConfigKey)
            UserDefaults.standard.synchronize()
        }

        // Increment version counter to signal data changed.
        // entityUUID is already uppercase from above
        let versionKey = "dataVersion_\(entityUUID)"
        let currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        let newVersion = currentVersion + 1
        UserDefaults.standard.set(newVersion, forKey: versionKey)
        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.set(newVersion, forKey: versionKey)
        }

        // Post Darwin notification (best effort - may not wake suspended extension)
        DarwinNotificationCenter.shared.postSwapAction()

        WidgetCenter.shared.reloadAllTimelines()

        let result = "Swapped \(nameA) (position \(positionA)) with \(nameB) (position \(positionB)) in \"\(widget.name)\". Touch the widget to refresh."
        return .result(dialog: IntentDialog(stringLiteral: result))
    }

    private func itemLabel(_ item: WidgetItem) -> String {
        switch item.displayType {
        case .icon:   return item.sfSymbolName ?? "icon"
        case .text:   return "\"\(item.customText ?? "text")\""
        case .image:  return "image"
        case .qrCode: return "QR code"
        }
    }
}

// MARK: - Debug Intent (for testing)

struct DebugWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Debug Widget State"
    static var description = IntentDescription("Shows current widget data state for debugging.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Widget",
               description: "The Grid Widget to debug.")
    var widget: GridWidgetEntity

    init() {}
    init(widget: GridWidgetEntity) { self.widget = widget }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard widget.id != "none" else {
            return .result(dialog: IntentDialog(stringLiteral: "No widgets found"))
        }

        let entityUUIDUpper = widget.id.uppercased()
        let entityUUIDLower = widget.id
        
        var info = "Widget: \(widget.name)\n"
        info += "Widget.id UPPER: \(entityUUIDUpper)\n"
        info += "Widget.id lower: \(entityUUIDLower)\n"

        let orderKeyUpper = "itemOrder_\(entityUUIDUpper)"
        let orderKeyLower = "itemOrder_\(entityUUIDLower)"
        info += "Key UPPER: \(orderKeyUpper)\n"
        info += "Key lower: \(orderKeyLower)\n"

        let configs = (try? SharedStorage.shared.loadConfigurations()) ?? []
        
        if let config = configs.first(where: { $0.id.uuidString == widget.id }) {
            info += "Config found: \(config.items.count) items\n"
        } else {
            info += "Config NOT found\n"
        }

        info += "Order UPPER: "
        if let order = SharedStorage.shared.gatherReadOverride(forKey: orderKeyUpper) {
            info += "FOUND '\(order)'\n"
        } else {
            info += "NOT FOUND\n"
        }
        
        info += "Order lower: "
        if let order = SharedStorage.shared.gatherReadOverride(forKey: orderKeyLower) {
            info += "FOUND '\(order)'\n"
        } else {
            info += "NOT FOUND\n"
        }

        return .result(dialog: IntentDialog(stringLiteral: info))
    }
}

// MARK: - Test Refresh Intent

struct TestRefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Test Widget Refresh"
    static var description = IntentDescription("Writes a timestamp. If widget shows this timestamp, refresh works.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Widget",
               description: "The Grid Widget to test.")
    var widget: GridWidgetEntity

    init() {}
    init(widget: GridWidgetEntity) { self.widget = widget }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard widget.id != "none" else {
            return .result(dialog: IntentDialog(stringLiteral: "No widgets found"))
        }

        let entityUUID = widget.id.uppercased()
        
        // Write current timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let timestampKey = "testTimestamp_\(entityUUID)"
        UserDefaults.standard.set(timestamp, forKey: timestampKey)
        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.set(timestamp, forKey: timestampKey)
        }
        
        // Increment version to trigger refresh
        let versionKey = "dataVersion_\(entityUUID)"
        let currentVersion = UserDefaults.standard.integer(forKey: versionKey)
        let newVersion = currentVersion + 1
        UserDefaults.standard.set(newVersion, forKey: versionKey)
        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.set(newVersion, forKey: versionKey)
        }
        
        DarwinNotificationCenter.shared.postSwapAction()
        WidgetCenter.shared.reloadAllTimelines()
        
        let formattedTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        return .result(dialog: IntentDialog(stringLiteral: "Wrote timestamp: \(formattedTime). Touch widget to check if it updates."))
    }
}

// MARK: - Debug Storage Intent

/// Diagnostic shortcut to show what storage the main app can access.
/// Use this to debug widget refresh issues with sideloaded apps.
struct DebugStorageIntent: AppIntent {
    static var title: LocalizedStringResource = "Debug Widget Storage"
    static var description = IntentDescription("Shows which storage the app can access for widget configs.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var info = "=== WIDGET STORAGE DEBUG ===\n\n"
        // Try to read widget debug file from Documents folder
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent("widget_debug.txt")
            if let data = try? Data(contentsOf: url),
               let widgetDebug = String(data: data, encoding: .utf8) {
                info += "=== WIDGET EXTENSION DEBUG (from file) ===\n"
                info += widgetDebug
                info += "\n\n"
            }
        }
        
        // Check keychain
        let kcGroup = SharedStorage.sharedKeychainGroup ?? "nil"
        let kcHasData = SharedStorage.shared.keychainHasConfigs
        info += "Keychain group: \(kcGroup)\n"
        info += "Keychain has configs: \(kcHasData)\n\n"
        
        // Check each App Group candidate
        for id in SharedStorage.appGroupCandidates {
            let hasContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
            let hasData = UserDefaults(suiteName: id)?.data(forKey: SharedStorage.configKey) != nil
            var fileExists = false
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                let url = container.appendingPathComponent("widgetConfigs.json")
                fileExists = FileManager.default.fileExists(atPath: url.path)
            }
            let shortId = id.replacingOccurrences(of: "group.", with: "")
            info += "[\(shortId)]\n"
            info += "  Container: \(hasContainer ? "✓" : "✗")\n"
            info += "  UserDefaults data: \(hasData ? "✓" : "✗")\n"
            info += "  File exists: \(fileExists ? "✓" : "✗")\n\n"
        }
        
        // Check UserDefaults.standard directly
        let standardKey = SharedStorage.configKey
        let standardData = UserDefaults.standard.data(forKey: standardKey)
        let standardSize = standardData?.count ?? 0
        info += "[UserDefaults.standard] has \(standardSize) bytes for \(standardKey)\n\n"

        // Show getActiveStorageName result
        let activeStorage = SharedStorage.shared.debugReadSource(forKey: SharedStorage.configKey)
        info += "getActiveStorageName(): \(activeStorage)\n\n"

        // Load and show configs
        let configs = (try? SharedStorage.shared.loadConfigurations()) ?? []
        info += "Configs loaded: \(configs.count)\n"
        for (i, c) in configs.prefix(5).enumerated() {
            info += "[\(i)] \(c.name)\n"
            info += "    UUID: \(c.id.uuidString)\n"
            info += "    Items: \(c.items.count)\n"
        }
        
        return .result(dialog: IntentDialog(stringLiteral: info))
    }
}


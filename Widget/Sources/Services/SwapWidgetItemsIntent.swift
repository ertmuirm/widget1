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

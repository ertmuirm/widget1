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
    static var description = IntentDescription("Swaps two items in a Grid Widget by their positions. Position 1 is the top-left cell. Positions beyond the grid size (e.g. position 10 in a 3x3 widget) refer to pre-configured bench items. The widget updates instantly on the home screen.")
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
            return .result(dialog: IntentDialog(stringLiteral:
                "No grid widgets found. Create one in the app first."))
        }

        var configs = (try? SharedStorage.shared.loadConfigurations()) ?? []
        guard let configIdx = configs.firstIndex(where: { $0.id.uuidString == widget.id }) else {
            return .result(dialog: IntentDialog(stringLiteral:
                "Widget \"\(widget.name)\" not found. It may have been deleted."))
        }

        let a = positionA - 1   // convert to 0-based
        let b = positionB - 1
        var config = configs[configIdx]
        let count = config.items.count

        guard a >= 0, a < count else {
            return .result(dialog: IntentDialog(stringLiteral:
                "Position \(positionA) is out of range. \"\(widget.name)\" has \(count) configured item(s)."))
        }
        guard b >= 0, b < count else {
            return .result(dialog: IntentDialog(stringLiteral:
                "Position \(positionB) is out of range. \"\(widget.name)\" has \(count) configured item(s)."))
        }
        guard a != b else {
            return .result(dialog: IntentDialog(stringLiteral:
                "Both positions are the same — nothing to swap."))
        }

        let nameA = itemLabel(config.items[a])
        let nameB = itemLabel(config.items[b])

        config.items.swapAt(a, b)
        configs[configIdx] = config

        try SharedStorage.shared.saveConfigurations(configs)

        // Write a lightweight item-order override so the widget extension can apply the
        // new order even when cross-process SharedStorage reads fail (e.g. on SideStore).
        let orderKey = "itemOrder_\(widget.id)"
        let orderValue = config.items.map { $0.id.uuidString }.joined(separator: ",")
        SharedStorage.shared.scatterWriteOverride(orderValue, forKey: orderKey)

        WidgetCenter.shared.reloadAllTimelines()

        return .result(dialog: IntentDialog(stringLiteral:
            "Swapped \(nameA) (position \(positionA)) with \(nameB) (position \(positionB)) in \"\(widget.name)\"."))
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

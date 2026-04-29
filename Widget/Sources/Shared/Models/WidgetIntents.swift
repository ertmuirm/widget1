import AppIntents
import WidgetKit

// MARK: - Shared helper

private func filteredEntities(size: WidgetSize) -> [(id: String, name: String)] {
    let configs = (try? SharedStorage.shared.loadConfigurations()) ?? []
    return configs
        .filter { $0.size == size }
        .map { (id: $0.id.uuidString, name: $0.name) }
}

private func allEntities() -> [(id: String, name: String)] {
    let configs = (try? SharedStorage.shared.loadConfigurations()) ?? []
    return configs.map { (id: $0.id.uuidString, name: $0.name) }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
    let showItemLabels: Bool
    let debugInfo: String

    init(date: Date, configuration: WidgetConfig,
         showItemLabels: Bool = SharedStorage.shared.showItemLabels,
         debugInfo: String = "") {
        self.date = date
        self.configuration = configuration
        self.showItemLabels = showItemLabels
        self.debugInfo = debugInfo
    }
}

// MARK: - Shared provider logic

private func makeEntry(configID: String?) -> WidgetEntry {
    let storage = SharedStorage.shared

    // Keychain status (SharedStorage.sharedKeychainGroup probes at first access)
    let kcGroup = SharedStorage.sharedKeychainGroup ?? "nil"
    let kcLabel = kcGroup.hasSuffix("com.iosmirror.shared") ? "ok" : (kcGroup == "nil" ? "nil" : "?")
    let kcStatus = "kc[\(kcLabel)]"

    // Per-group UserDefaults status
    let groupStatus: String = SharedStorage.appGroupCandidates.enumerated().map { i, id in
        guard let ud = UserDefaults(suiteName: id) else { return "g\(i):nil" }
        return ud.data(forKey: SharedStorage.configKey) != nil ? "g\(i):ok" : "g\(i):empty"
    }.joined(separator: "|")

    let allConfigs = (try? storage.loadConfigurations()) ?? []

    let config: WidgetConfig
    let foundLabel: String
    if let id = configID, id != "none", let found = storage.getConfig(id: id) {
        config = found
        foundLabel = "cfg:\(found.name)"
    } else {
        config = WidgetConfig.defaultConfiguration
        foundLabel = "default"
    }

    let kcDataStatus = storage.keychainHasConfigs ? "data:ok" : "data:empty"
    storage.appendExtensionLog("entry cfgs=\(allConfigs.count) \(kcStatus):\(kcDataStatus) \(groupStatus) req=\(configID ?? "nil")")

    let debugInfo = "req:\(configID ?? "nil") cfgs:\(allConfigs.count) \(foundLabel)\n\(kcStatus):\(kcDataStatus)\n\(groupStatus)"
    return WidgetEntry(date: Date(), configuration: config,
                       showItemLabels: storage.showItemLabels,
                       debugInfo: debugInfo)
}

private func makeTimeline(configID: String?) -> Timeline<WidgetEntry> {
    let entry = makeEntry(configID: configID)
    let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    return Timeline(entries: [entry], policy: .after(next))
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: SMALL WIDGET — home screen Small (3×3, systemSmall)
// MARK: ─────────────────────────────────────────────────────────────────

struct SmallWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Small Widget")
    }
    static var defaultQuery = SmallWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct SmallWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SmallWidgetEntity] {
        filteredEntities(size: .systemSmall)
            .filter { identifiers.contains($0.id) }
            .map { SmallWidgetEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [SmallWidgetEntity] {
        let list = filteredEntities(size: .systemSmall)
        if list.isEmpty { return [SmallWidgetEntity(id: "none", name: "No Small Widgets")] }
        return list.map { SmallWidgetEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> SmallWidgetEntity? {
        filteredEntities(size: .systemSmall).first.map { SmallWidgetEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectSmallWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Small Widget"
    static var description = IntentDescription("Choose a small (3×3) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: SmallWidgetEntity?
    init() {}
    init(selectedWidget: SmallWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct SmallBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectSmallWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectSmallWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: MEDIUM WIDGET — home screen Medium (6×3, systemMedium)
// MARK: ─────────────────────────────────────────────────────────────────

struct MediumWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Medium Widget")
    }
    static var defaultQuery = MediumWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct MediumWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MediumWidgetEntity] {
        filteredEntities(size: .systemMedium)
            .filter { identifiers.contains($0.id) }
            .map { MediumWidgetEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [MediumWidgetEntity] {
        let list = filteredEntities(size: .systemMedium)
        if list.isEmpty { return [MediumWidgetEntity(id: "none", name: "No Medium Widgets")] }
        return list.map { MediumWidgetEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> MediumWidgetEntity? {
        filteredEntities(size: .systemMedium).first.map { MediumWidgetEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectMediumWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Medium Widget"
    static var description = IntentDescription("Choose a medium (6×3) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: MediumWidgetEntity?
    init() {}
    init(selectedWidget: MediumWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct MediumBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectMediumWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectMediumWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: LARGE WIDGET — home screen Large (6×6, systemLarge)
// MARK: ─────────────────────────────────────────────────────────────────

struct LargeWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Large Widget")
    }
    static var defaultQuery = LargeWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct LargeWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LargeWidgetEntity] {
        filteredEntities(size: .systemLarge)
            .filter { identifiers.contains($0.id) }
            .map { LargeWidgetEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [LargeWidgetEntity] {
        let list = filteredEntities(size: .systemLarge)
        if list.isEmpty { return [LargeWidgetEntity(id: "none", name: "No Large Widgets")] }
        return list.map { LargeWidgetEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> LargeWidgetEntity? {
        filteredEntities(size: .systemLarge).first.map { LargeWidgetEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectLargeWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Large Widget"
    static var description = IntentDescription("Choose a large (6×6) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: LargeWidgetEntity?
    init() {}
    init(selectedWidget: LargeWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct LargeBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectLargeWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectLargeWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: LOCK SCREEN WIDGETS (accessory families)
// MARK: ─────────────────────────────────────────────────────────────────

struct LockWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Lock Screen Widget")
    }
    static var defaultQuery = LockWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct LockWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LockWidgetEntity] {
        allEntities()
            .filter { identifiers.contains($0.id) }
            .map { LockWidgetEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [LockWidgetEntity] {
        let list = allEntities()
        if list.isEmpty { return [LockWidgetEntity(id: "none", name: "No Widgets")] }
        return list.map { LockWidgetEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> LockWidgetEntity? {
        allEntities().first.map { LockWidgetEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectLockWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Lock Screen Widget"
    static var description = IntentDescription("Choose a widget for the Lock Screen")
    @Parameter(title: "Widget") var selectedWidget: LockWidgetEntity?
    init() {}
    init(selectedWidget: LockWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct LockBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectLockWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectLockWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: - Legacy / Generic (backwards-compat for any existing placed widgets)

struct WidgetNameEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Widget")
    }
    static var defaultQuery = WidgetNameQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct WidgetNameQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetNameEntity] {
        allEntities()
            .filter { identifiers.contains($0.id) }
            .map { WidgetNameEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [WidgetNameEntity] {
        let list = allEntities()
        if list.isEmpty { return [WidgetNameEntity(id: "none", name: "No Configurations")] }
        return list.map { WidgetNameEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> WidgetNameEntity? {
        allEntities().first.map { WidgetNameEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget"
    static var description = IntentDescription("Choose which widget configuration to display")
    @Parameter(title: "Widget") var selectedWidget: WidgetNameEntity?
    init() {}
    init(selectedWidget: WidgetNameEntity?) { self.selectedWidget = selectedWidget }
}

struct BroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

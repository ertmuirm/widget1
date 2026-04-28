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

    init(date: Date, configuration: WidgetConfig, showItemLabels: Bool = SharedStorage.shared.showItemLabels) {
        self.date = date
        self.configuration = configuration
        self.showItemLabels = showItemLabels
    }
}

// MARK: - Shared provider logic

private func makeEntry(configID: String?, fallbackSize: WidgetSize) -> WidgetEntry {
    let config: WidgetConfig
    if let id = configID, let found = SharedStorage.shared.getConfig(id: id) {
        config = found
    } else {
        config = WidgetConfig.defaultConfiguration
    }
    return WidgetEntry(date: Date(), configuration: config)
}

private func makeTimeline(configID: String?, fallbackSize: WidgetSize) -> Timeline<WidgetEntry> {
    let entry = makeEntry(configID: configID, fallbackSize: fallbackSize)
    let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    return Timeline(entries: [entry], policy: .after(next))
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: SMALL WIDGET (1×1)
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
    static var description = IntentDescription("Choose a small (1×1) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: SmallWidgetEntity?
    init() {}
    init(selectedWidget: SmallWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct SmallBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectSmallWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id, fallbackSize: .systemSmall)
    }
    func timeline(for configuration: SelectSmallWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id, fallbackSize: .systemSmall)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: MEDIUM WIDGET (3×3)
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
    static var description = IntentDescription("Choose a medium (3×3) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: MediumWidgetEntity?
    init() {}
    init(selectedWidget: MediumWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct MediumBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectMediumWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id, fallbackSize: .systemMedium)
    }
    func timeline(for configuration: SelectMediumWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id, fallbackSize: .systemMedium)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: LARGE WIDGET (6×3)
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
    static var description = IntentDescription("Choose a large (6×3) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: LargeWidgetEntity?
    init() {}
    init(selectedWidget: LargeWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct LargeBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectLargeWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id, fallbackSize: .systemLarge)
    }
    func timeline(for configuration: SelectLargeWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id, fallbackSize: .systemLarge)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: EXTRA LARGE WIDGET (6×6)
// MARK: ─────────────────────────────────────────────────────────────────

struct ExtraLargeWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Extra Large Widget")
    }
    static var defaultQuery = ExtraLargeWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct ExtraLargeWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ExtraLargeWidgetEntity] {
        filteredEntities(size: .systemExtraLarge)
            .filter { identifiers.contains($0.id) }
            .map { ExtraLargeWidgetEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [ExtraLargeWidgetEntity] {
        let list = filteredEntities(size: .systemExtraLarge)
        if list.isEmpty { return [ExtraLargeWidgetEntity(id: "none", name: "No Extra Large Widgets")] }
        return list.map { ExtraLargeWidgetEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> ExtraLargeWidgetEntity? {
        filteredEntities(size: .systemExtraLarge).first.map { ExtraLargeWidgetEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectExtraLargeWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Extra Large Widget"
    static var description = IntentDescription("Choose an extra large (6×6) widget configuration")
    @Parameter(title: "Widget") var selectedWidget: ExtraLargeWidgetEntity?
    init() {}
    init(selectedWidget: ExtraLargeWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct ExtraLargeBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectExtraLargeWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id, fallbackSize: .systemExtraLarge)
    }
    func timeline(for configuration: SelectExtraLargeWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id, fallbackSize: .systemExtraLarge)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: LOCK SCREEN WIDGETS
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
        makeEntry(configID: configuration.selectedWidget?.id, fallbackSize: .systemSmall)
    }
    func timeline(for configuration: SelectLockWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id, fallbackSize: .systemSmall)
    }
}

// MARK: - Legacy / Generic (kept for backwards compatibility with any existing placed widgets)

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
        makeEntry(configID: configuration.selectedWidget?.id, fallbackSize: .systemSmall)
    }
    func timeline(for configuration: SelectWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id, fallbackSize: .systemSmall)
    }
}

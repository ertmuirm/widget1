import AppIntents
import WidgetKit

// MARK: - Entity ID encoding
//
// Entity IDs have the format "<uuid>|<base64-json>" where the base64 portion is
// the full WidgetConfig JSON. This lets entities(for:) reconstruct a config from
// just the stored ID — no cross-process data sharing required. iOS re-resolves
// entities on every timeline refresh; if the query returns an empty array the
// selectedWidget becomes nil. Embedding the config in the ID prevents that.

private func encodeEntityID(_ config: WidgetConfig) -> String {
    guard let data = try? {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; return try enc.encode(config)
    }() else { return config.id.uuidString }
    return "\(config.id.uuidString)|\(data.base64EncodedString())"
}

private func uuidFromEntityID(_ entityID: String) -> String {
    String(entityID.split(separator: "|", maxSplits: 1).first ?? Substring(entityID))
}

private func decodeConfigFromID(_ entityID: String) -> WidgetConfig? {
    let parts = entityID.split(separator: "|", maxSplits: 1)
    guard parts.count == 2, let data = Data(base64Encoded: String(parts[1])) else { return nil }
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    return try? dec.decode(WidgetConfig.self, from: data)
}

// MARK: - URL resolution (shared between makeEntry diagnostics and WidgetEntryView)

/// Resolves the tap URL for a widget item. Returns nil when no action is configured,
/// the payload is empty/whitespace-only, or the action type is appIntent.
func resolveItemURL(_ item: WidgetItem) -> URL? {
    guard let action = item.action else { return nil }
    let raw = action.payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    switch action.type {
    case .urlScheme, .appIntent:
        // .appIntent stores a URL scheme selected from the predefined list
        return URL(string: raw)
            ?? URL(string: raw.addingPercentEncoding(
                withAllowedCharacters: .urlFragmentAllowed) ?? raw)
    case .shortcut:
        guard let encoded = raw.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "shortcuts://run-shortcut?name=\(encoded)")
    }
}

// MARK: - Shared helpers

private func filteredConfigs(size: WidgetSize) -> [WidgetConfig] {
    ((try? SharedStorage.shared.loadConfigurations()) ?? []).filter { $0.size == size }
}

private func allConfigs() -> [WidgetConfig] {
    (try? SharedStorage.shared.loadConfigurations()) ?? []
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
    let showItemLabels: Bool

    init(date: Date, configuration: WidgetConfig,
         showItemLabels: Bool = SharedStorage.shared.showItemLabels) {
        self.date = date
        self.configuration = configuration
        self.showItemLabels = showItemLabels
    }
}

// MARK: - Shared provider logic

private func makeEntry(configID: String?) -> WidgetEntry {
    let storage = SharedStorage.shared
    let liveConfigs = (try? storage.loadConfigurations()) ?? []

    let config: WidgetConfig
    if let id = configID, id != "none" {
        let uuid = uuidFromEntityID(id)
        if let found = liveConfigs.first(where: { $0.id.uuidString == uuid }) {
            config = found
        } else if let embedded = decodeConfigFromID(id) {
            config = embedded
        } else {
            config = .defaultConfiguration
        }
    } else {
        config = .defaultConfiguration
    }

    let showLabels = config.showItemLabels ?? storage.showItemLabels
    return WidgetEntry(date: Date(), configuration: config, showItemLabels: showLabels)
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
        let configs = filteredConfigs(size: .systemSmall)
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            // Fresh data from live storage
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return SmallWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            // Reconstruct from embedded config in the stored ID
            if let c = decodeConfigFromID(storedID) {
                return SmallWidgetEntity(id: storedID, name: c.name)
            }
            // Preserve the selection even if config is unavailable
            return SmallWidgetEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [SmallWidgetEntity] {
        let list = filteredConfigs(size: .systemSmall)
        if list.isEmpty { return [SmallWidgetEntity(id: "none", name: "No Small Widgets")] }
        return list.map { SmallWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> SmallWidgetEntity? {
        filteredConfigs(size: .systemSmall).first.map { SmallWidgetEntity(id: encodeEntityID($0), name: $0.name) }
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
        let configs = filteredConfigs(size: .systemMedium)
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return MediumWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return MediumWidgetEntity(id: storedID, name: c.name)
            }
            return MediumWidgetEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [MediumWidgetEntity] {
        let list = filteredConfigs(size: .systemMedium)
        if list.isEmpty { return [MediumWidgetEntity(id: "none", name: "No Medium Widgets")] }
        return list.map { MediumWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> MediumWidgetEntity? {
        filteredConfigs(size: .systemMedium).first.map { MediumWidgetEntity(id: encodeEntityID($0), name: $0.name) }
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
        let configs = filteredConfigs(size: .systemLarge)
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return LargeWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return LargeWidgetEntity(id: storedID, name: c.name)
            }
            return LargeWidgetEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [LargeWidgetEntity] {
        let list = filteredConfigs(size: .systemLarge)
        if list.isEmpty { return [LargeWidgetEntity(id: "none", name: "No Large Widgets")] }
        return list.map { LargeWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> LargeWidgetEntity? {
        filteredConfigs(size: .systemLarge).first.map { LargeWidgetEntity(id: encodeEntityID($0), name: $0.name) }
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
        let configs = allConfigs()
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return LockWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return LockWidgetEntity(id: storedID, name: c.name)
            }
            return LockWidgetEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [LockWidgetEntity] {
        let list = allConfigs()
        if list.isEmpty { return [LockWidgetEntity(id: "none", name: "No Widgets")] }
        return list.map { LockWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> LockWidgetEntity? {
        allConfigs().first.map { LockWidgetEntity(id: encodeEntityID($0), name: $0.name) }
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
        let configs = allConfigs()
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return WidgetNameEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return WidgetNameEntity(id: storedID, name: c.name)
            }
            return WidgetNameEntity(id: storedID, name: "Widget")
        }
    }
    func suggestedEntities() async throws -> [WidgetNameEntity] {
        let list = allConfigs()
        if list.isEmpty { return [WidgetNameEntity(id: "none", name: "No Configurations")] }
        return list.map { WidgetNameEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> WidgetNameEntity? {
        allConfigs().first.map { WidgetNameEntity(id: encodeEntityID($0), name: $0.name) }
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

// MARK: ─────────────────────────────────────────────────────────────────
// MARK: IMAGE SLIDESHOW WIDGET
// MARK: ─────────────────────────────────────────────────────────────────

private func imageSlideshowConfigs() -> [WidgetConfig] {
    allConfigs().filter { $0.widgetKind == .imageSlideshow }
}

struct ImageWidgetEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Image Widget")
    }
    static var defaultQuery = ImageWidgetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct ImageWidgetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ImageWidgetEntity] {
        let configs = imageSlideshowConfigs()
        return identifiers.map { storedID in
            let uuid = uuidFromEntityID(storedID)
            if let c = configs.first(where: { $0.id.uuidString == uuid }) {
                return ImageWidgetEntity(id: encodeEntityID(c), name: c.name)
            }
            if let c = decodeConfigFromID(storedID) {
                return ImageWidgetEntity(id: storedID, name: c.name)
            }
            return ImageWidgetEntity(id: storedID, name: "Image Widget")
        }
    }
    func suggestedEntities() async throws -> [ImageWidgetEntity] {
        let list = imageSlideshowConfigs()
        if list.isEmpty { return [ImageWidgetEntity(id: "none", name: "No Image Widgets")] }
        return list.map { ImageWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> ImageWidgetEntity? {
        imageSlideshowConfigs().first.map { ImageWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectImageWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Image Widget"
    static var description = IntentDescription("Choose an image slideshow widget")
    @Parameter(title: "Widget") var selectedWidget: ImageWidgetEntity?
    init() {}
    init(selectedWidget: ImageWidgetEntity?) { self.selectedWidget = selectedWidget }
}

struct ImageBroadcastProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: .defaultConfiguration)
    }
    func snapshot(for configuration: SelectImageWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configID: configuration.selectedWidget?.id)
    }
    func timeline(for configuration: SelectImageWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        makeTimeline(configID: configuration.selectedWidget?.id)
    }
}

// MARK: - Advance Image Intent (cycles slides in an image slideshow widget)

struct AdvanceImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Advance Image"

    @Parameter(title: "Widget ID") var widgetID: String
    @Parameter(title: "Forward")   var forward: Bool

    init() { widgetID = ""; forward = true }
    init(widgetID: String, forward: Bool) { self.widgetID = widgetID; self.forward = forward }

    func perform() async throws -> some IntentResult {
        var configs = (try? SharedStorage.shared.loadConfigurations()) ?? []
        guard let idx = configs.firstIndex(where: { $0.id.uuidString == widgetID }) else {
            return .result()
        }
        let count = configs[idx].slides?.count ?? 0
        guard count > 1 else { return .result() }
        let current = configs[idx].currentSlideIndex ?? 0
        configs[idx].currentSlideIndex = forward
            ? (current + 1) % count
            : (current - 1 + count) % count
        try? SharedStorage.shared.saveConfigurations(configs)
        return .result()
    }
}

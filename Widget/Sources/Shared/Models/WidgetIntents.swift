import AppIntents
import WidgetKit
import UIKit

// MARK: - Entity ID encoding
//
// Entity IDs have the format "<uuid>|<base64-json>" where the base64 portion is
// the full WidgetConfig JSON. This lets entities(for:) reconstruct a config from
// just the stored ID — no cross-process data sharing required. iOS re-resolves
// entities on every timeline refresh; if the query returns an empty array the
// selectedWidget becomes nil. Embedding the config in the ID prevents that.

/// Downsample image data to a small thumbnail for embedding in entity IDs.
/// Keeps entity IDs compact (~2-4 KB/image) while still providing a fallback
/// when the app-group / keychain channel is unavailable (e.g. SideStore free accounts).
private func thumbnailData(from data: Data, maxDimension: CGFloat = 80) -> Data? {
    guard let src = UIImage(data: data) else { return nil }
    let s = src.size
    guard s.width > 0, s.height > 0 else { return nil }
    let factor = min(maxDimension / s.width, maxDimension / s.height, 1.0)
    if factor >= 1.0 { return data }
    let newSize = CGSize(width: (s.width * factor).rounded(), height: (s.height * factor).rounded())
    let thumb = UIGraphicsImageRenderer(size: newSize).image { _ in
        src.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return thumb.jpegData(compressionQuality: 0.5)
}

private func encodeEntityID(_ config: WidgetConfig) -> String {
    // Downsample imageData to small thumbnails before embedding in the entity ID.
    // This keeps entity IDs manageable (~2-4 KB/image) while still providing a
    // fallback path when app-group / keychain storage is inaccessible in the extension.
    var lite = config
    if var slides = lite.slides {
        for i in slides.indices {
            if let d = slides[i].imageData {
                slides[i].imageData = thumbnailData(from: d) ?? d
            }
        }
        lite.slides = slides
    }
    for i in lite.items.indices {
        if let d = lite.items[i].imageData {
            lite.items[i].imageData = thumbnailData(from: d) ?? d
        }
    }
    guard let data = try? {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; return try enc.encode(lite)
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

/// Resolves a tap URL from a `WidgetAction`. Returns nil for empty/whitespace payloads.
func resolveURL(for action: WidgetAction) -> URL? {
    let raw = action.payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    switch action.type {
    case .urlScheme, .appIntent:
        let normalized = raw
        return URL(string: normalized)
            ?? URL(string: normalized.addingPercentEncoding(
                withAllowedCharacters: .urlFragmentAllowed) ?? normalized)
    case .shortcut:
        guard let encoded = raw.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "shortcuts://run-shortcut?name=\(encoded)")
    }
}

/// Resolves the tap URL for a widget item. Returns nil when no action is configured.
func resolveItemURL(_ item: WidgetItem) -> URL? {
    guard let action = item.action else { return nil }
    return resolveURL(for: action)
}

// MARK: - Shared helpers

private func filteredConfigs(size: WidgetSize) -> [WidgetConfig] {
    ((try? SharedStorage.shared.loadConfigurations()) ?? [])
        .filter { $0.size == size && $0.widgetKind != .imageSlideshow }
}

private func allConfigs() -> [WidgetConfig] {
    (try? SharedStorage.shared.loadConfigurations()) ?? []
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
    let showItemLabels: Bool
    /// The UUID extracted from the entity ID, which may differ from configuration.id
    /// when makeEntry() fell back to .defaultConfiguration (random UUID). Buttons in
    /// WidgetEntryView must use this UUID — not configuration.id — when constructing
    /// AdvanceImageIntent so the intent can match the correct slideIdx_ key.
    let entityUUID: String

    init(date: Date, configuration: WidgetConfig,
         showItemLabels: Bool = SharedStorage.shared.showItemLabels,
         entityUUID: String = "") {
        self.date = date
        self.configuration = configuration
        self.showItemLabels = showItemLabels
        self.entityUUID = entityUUID.isEmpty ? configuration.id.uuidString : entityUUID
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
        } else if var embedded = decodeConfigFromID(id) {
            // Populate imageData for slides/items not already populated by loadConfigurations
            if embedded.slides != nil {
                for j in embedded.slides!.indices where embedded.slides![j].imageData == nil {
                    let fn = embedded.slides![j].filename
                    if !fn.isEmpty {
                        embedded.slides![j].imageData = storage.loadWidgetImageData(filename: fn)
                    }
                }
            }
            for j in embedded.items.indices where embedded.items[j].imageData == nil {
                if embedded.items[j].displayType == .image,
                   let fn = embedded.items[j].customImageFilename, !fn.isEmpty {
                    embedded.items[j].imageData = storage.loadWidgetImageData(filename: fn)
                }
            }
            config = embedded
        } else {
            config = .defaultConfiguration
        }
    } else {
        config = .defaultConfiguration
    }

    // Apply slide index written by AdvanceImageIntent as a lightweight override.
    // This fires when saveConfigurations didn't cross the process boundary so the
    // config we just loaded still has the old slide index.
    // Use the UUID from the entity ID parameter (not config.id) so that even when
    // SharedStorage is unavailable and config falls back to .defaultConfiguration
    // (which has a fresh random UUID), we still look up the key AdvanceImageIntent wrote.
    var finalConfig = config
    let entityUUID = configID.map { uuidFromEntityID($0) } ?? config.id.uuidString
    let idxKey = "slideIdx_\(entityUUID)"
    var slideOverride: Int? = nil
    for id in SharedStorage.appGroupCandidates {
        if let v = UserDefaults(suiteName: id)?.object(forKey: idxKey) as? Int {
            slideOverride = v; break
        }
    }
    if slideOverride == nil {
        slideOverride = UserDefaults.standard.object(forKey: idxKey) as? Int
    }
    if let v = slideOverride { finalConfig.currentSlideIndex = v }

    // Only keep imageData for the ACTIVE slide. loadConfigurations() eagerly loads
    // every slide's image; holding them all decoded simultaneously easily blows the
    // 30 MB WidgetKit process memory limit and causes a silent blank-widget kill.
    if var slides = finalConfig.slides, !slides.isEmpty {
        let activeIdx = min(finalConfig.currentSlideIndex ?? 0, slides.count - 1)
        for j in slides.indices {
            if j == activeIdx {
                // Ensure the active slide has data (may be nil when config was loaded
                // from the stripped JSON path where saveConfigurations omits imageData).
                if slides[j].imageData == nil, !slides[j].filename.isEmpty {
                    slides[j].imageData = storage.loadWidgetImageData(filename: slides[j].filename)
                }
            } else {
                slides[j].imageData = nil
            }
        }
        finalConfig.slides = slides
    }

    let showLabels = finalConfig.showItemLabels ?? storage.showItemLabels
    return WidgetEntry(date: Date(), configuration: finalConfig,
                       showItemLabels: showLabels, entityUUID: entityUUID)
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
        // Prefer dedicated lock-screen configs; fall back to all configs
        var list = allConfigs().filter { $0.widgetKind == .lockScreen }
        if list.isEmpty { list = allConfigs() }
        if list.isEmpty { return [LockWidgetEntity(id: "none", name: "No Widgets")] }
        return list.map { LockWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> LockWidgetEntity? {
        let ls = allConfigs().filter { $0.widgetKind == .lockScreen }
        let pick = ls.first ?? allConfigs().first
        return pick.map { LockWidgetEntity(id: encodeEntityID($0), name: $0.name) }
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
        TypeDisplayRepresentation(name: "Code Widget")
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
            return ImageWidgetEntity(id: storedID, name: "Code Widget")
        }
    }
    func suggestedEntities() async throws -> [ImageWidgetEntity] {
        let list = imageSlideshowConfigs()
        if list.isEmpty { return [ImageWidgetEntity(id: "none", name: "No Code Widgets")] }
        return list.map { ImageWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
    func defaultResult() async -> ImageWidgetEntity? {
        imageSlideshowConfigs().first.map { ImageWidgetEntity(id: encodeEntityID($0), name: $0.name) }
    }
}

struct SelectImageWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Code Widget"
    static var description = IntentDescription("Choose a code widget")
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

// MARK: - No-Op Intent (prevents app from opening when empty widget areas are tapped)

/// Placed on every empty grid cell and the widget background so that tapping
/// anywhere without a real action does nothing instead of opening the host app.
struct NoOpIntent: AppIntent {
    static var title: LocalizedStringResource = "No Action"
    static var openAppWhenRun: Bool = false
    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - Advance Image Intent (cycles slides in an image slideshow widget)

struct AdvanceImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Advance Image"
    /// Without this, tapping the button opens the host app instead of running
    /// the intent in-place inside the extension process.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Widget ID")   var widgetID: String
    @Parameter(title: "Forward")     var forward: Bool
    /// Total number of slides — embedded in the intent so perform() never needs
    /// to call SharedStorage.loadConfigurations(), which returns [] on SideStore
    /// (app group entitlement stripped) and would cause an early return.
    @Parameter(title: "Slide Count") var slideCount: Int

    init() { widgetID = ""; forward = true; slideCount = 0 }
    init(widgetID: String, forward: Bool, slideCount: Int) {
        self.widgetID = widgetID; self.forward = forward; self.slideCount = slideCount
    }

    func perform() async throws -> some IntentResult {
        guard slideCount > 1 else { return .result() }

        // Read the current index from the lightweight UserDefaults key.
        // We deliberately avoid loadConfigurations() here: on SideStore the app-group
        // entitlement is stripped, so it always returns [], which previously caused
        // the firstIndex lookup to fail and the function to return early without
        // updating anything.
        let idxKey = "slideIdx_\(widgetID)"
        var currentIndex = 0
        for id in SharedStorage.appGroupCandidates {
            if let v = UserDefaults(suiteName: id)?.object(forKey: idxKey) as? Int {
                currentIndex = v; break
            }
        }
        if let v = UserDefaults.standard.object(forKey: idxKey) as? Int {
            currentIndex = v
        }

        let nextIndex = forward
            ? (currentIndex + 1) % slideCount
            : (currentIndex - 1 + slideCount) % slideCount

        // Write new index to every available store.
        for id in SharedStorage.appGroupCandidates {
            UserDefaults(suiteName: id)?.set(nextIndex, forKey: idxKey)
        }
        UserDefaults.standard.set(nextIndex, forKey: idxKey)

        // Best-effort: also update the persisted config so the index survives
        // a full timeline refresh that re-reads from SharedStorage.
        if var configs = try? SharedStorage.shared.loadConfigurations(),
           let idx = configs.firstIndex(where: { $0.id.uuidString == widgetID }) {
            configs[idx].currentSlideIndex = nextIndex
            try? SharedStorage.shared.saveConfigurations(configs)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastImage")
        return .result()
    }
}

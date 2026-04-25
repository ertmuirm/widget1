import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entity

struct WidgetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget"
    static var defaultQuery = WidgetEntityQuery()
    
    var id: String
    var name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - Entity Query

struct WidgetEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetEntity] {
        loadConfigs().filter { identifiers.contains($0.id) }.map { WidgetEntity(id: $0.id, name: $0.name) }
    }
    
    func suggestedEntities() async throws -> [WidgetEntity] {
        loadConfigs().map { WidgetEntity(id: $0.id, name: $0.name) }
    }
    
    func defaultResult() async -> WidgetEntity? {
        if let first = loadConfigs().first {
            return WidgetEntity(id: first.id, name: first.name)
        }
        return nil
    }
    
    private func loadConfigs() -> [WidgetConfig] {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.iosmirror")?.appendingPathComponent("configurations.json"),
              let data = try? Data(contentsOf: url),
              let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) else { return [] }
        return configs
    }
}

// MARK: - Widget Selection Intent

struct SelectWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget"
    static var description = IntentDescription("Select which widget to display")
    
    @EntityProperty(for: WidgetEntityQuery())
    var widget: WidgetEntity?
    
    init() {}
    init(widget: WidgetEntity?) { self.widget = widget }
}

// MARK: - Widget

struct BroadcastWidget: Widget {
    let kind: String = "BroadcastExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectWidgetIntent.self, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Widget")
        .description("Custom widgets")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Timeline Provider

struct Provider: AppIntentTimelineProvider {
    typealias Entry = WidgetEntry
    typealias Intent = SelectWidgetIntent
    
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
    }
    
    func snapshot(for configuration: SelectWidgetIntent, in context: Context) async -> WidgetEntry {
        let config = loadConfig(name: configuration.widget?.name)
        return WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
    }
    
    func timeline(for configuration: SelectWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let config = loadConfig(name: configuration.widget?.name)
        let entry = WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
    }
    
    private func loadConfig(name: String?) -> WidgetConfig? {
        guard let name = name,
              let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.iosmirror")?.appendingPathComponent("configurations.json"),
              let data = try? Data(contentsOf: url),
              let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) else { return nil }
        return configs.first { $0.name == name }
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
}

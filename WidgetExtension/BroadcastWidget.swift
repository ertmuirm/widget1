import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entity for Selection

struct WidgetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget"
    static var defaultQuery = WidgetEntityQuery()
    
    var id: String
    var name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    init(from config: WidgetConfig) {
        self.id = config.id.uuidString
        self.name = config.name
    }
}

struct WidgetEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetEntity] {
        let configs = loadConfigurations()
        return configs.filter { identifiers.contains($0.id) }.map { WidgetEntity(from: $0) }
    }
    
    func suggestedEntities() async throws -> [WidgetEntity] {
        let configs = loadConfigurations()
        return configs.map { WidgetEntity(from: $0) }
    }
    
    func defaultResult() async -> WidgetEntity? {
        let configs = loadConfigurations()
        guard let first = configs.first else { return nil }
        return WidgetEntity(from: first)
    }
    
    private func loadConfigurations() -> [WidgetConfig] {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.iosmirror"
        )?.appendingPathComponent("configurations.json") else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([WidgetConfig].self, from: data)
        } catch {
            return []
        }
    }
}

// MARK: - Widget Configuration Intent

struct WidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget"
    static var description = IntentDescription("Select which widget to display")
    
    @Parameter(title: "Widget")
    var widget: WidgetEntity
    
    init() {
        self.widget = WidgetEntity(id: "default", name: "Select a widget")
    }
    
    init(widget: WidgetEntity) {
        self.widget = widget
    }
}

// MARK: - Widget

struct BroadcastWidget: Widget {
    let kind: String = "BroadcastExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WidgetConfigurationIntent.self, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Widget")
        .description("Create custom widgets with customizable actions")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

// MARK: - Timeline Provider

struct Provider: AppIntentTimelineProvider {
    typealias Entry = WidgetEntry
    typealias Intent = WidgetConfigurationIntent
    
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
    }

    func snapshot(for configuration: WidgetConfigurationIntent, in context: Context) async -> WidgetEntry {
        if let uuid = UUID(uuidString: configuration.widget.id) {
            let config = loadConfiguration(id: uuid)
            return WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
        }
        return WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
    }

    func timeline(for configuration: WidgetConfigurationIntent, in context: Context) async -> Timeline<WidgetEntry> {
        if let uuid = UUID(uuidString: configuration.widget.id) {
            let config = loadConfiguration(id: uuid)
            let entry = WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        }
        let entry = WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
    }
    
    private func loadConfiguration(id: UUID) -> WidgetConfig? {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.iosmirror"
        )?.appendingPathComponent("configurations.json") else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let configs = try JSONDecoder().decode([WidgetConfig].self, from: data)
            return configs.first { $0.id == id }
        } catch {
            return nil
        }
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
}

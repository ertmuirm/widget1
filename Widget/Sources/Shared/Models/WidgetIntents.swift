import AppIntents
import WidgetKit

// MARK: - Widget Name Entity for App Intents

/// AppEntity representing a widget configuration for selection in the Edit Widget menu
struct WidgetNameEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Widget")
    }
    
    static var defaultQuery: WidgetNameQuery = WidgetNameQuery()
    
    var id: String
    var name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Widget Name Query

/// EntityQuery for fetching widget names from shared App Group storage
struct WidgetNameQuery: EntityQuery {
    private let appGroupID = StorageKeys.appGroupIdentifier
    
    func entities(for identifiers: [String]) async throws -> [WidgetNameEntity] {
        let savedNames = loadSavedNames()
        return savedNames
            .filter { identifiers.contains($0) }
            .map { WidgetNameEntity(id: $0, name: $0) }
    }
    
    func suggestedEntities() async throws -> [WidgetNameEntity] {
        let savedNames = loadSavedNames()
        let entities = savedNames.map { WidgetNameEntity(id: $0, name: $0) }
        
        // No data fallback
        if entities.isEmpty {
            return [WidgetNameEntity(id: "None Found", name: "None Found")]
        }
        
        return entities
    }
    
    func defaultResult() async -> WidgetNameEntity? {
        let savedNames = loadSavedNames()
        if let firstName = savedNames.first {
            return WidgetNameEntity(id: firstName, name: firstName)
        }
        return WidgetNameEntity(id: "None Found", name: "None Found")
    }
    
    private func loadSavedNames() -> [String] {
        // Load from shared UserDefaults
        if let defaults = UserDefaults(suiteName: appGroupID),
           let data = defaults.data(forKey: "widgetConfigurations"),
           let configurations = try? decodeConfigurations(from: data) {
            return configurations.map { $0.name }
        }
        
        // Fallback: load from file
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.appendingPathComponent("configurations.json"),
           let data = try? Data(contentsOf: url),
           let configurations = try? decodeConfigurations(from: data) {
            return configurations.map { $0.name }
        }
        
        return []
    }
    
    private func decodeConfigurations(from data: Data) throws -> [WidgetConfig] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WidgetConfig].self, from: data)
    }
}

// MARK: - Select Widget Intent

/// App Intent for configuring which widget to display
struct SelectWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget"
    static var description = IntentDescription("Choose which widget configuration to display")
    
    @Parameter(title: "Widget", query: WidgetNameQuery.self)
    var selectedWidget: WidgetNameEntity?
    
    init() {}
    
    init(selectedWidget: WidgetNameEntity?) {
        self.selectedWidget = selectedWidget
    }
}

// MARK: - Widget with AppIntentConfiguration

struct BroadcastWidget: Widget {
    let kind: String = "BroadcastExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectWidgetIntent.self, provider: BroadcastProvider()) { entry in
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

struct BroadcastProvider: AppIntentTimelineProvider {
    private let appGroupID = StorageKeys.appGroupIdentifier
    
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
    }

    func snapshot(for configuration: SelectWidgetIntent, in context: Context) async -> WidgetEntry {
        let config = loadConfig(name: configuration.selectedWidget?.name)
        return WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
    }

    func timeline(for configuration: SelectWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let config = loadConfig(name: configuration.selectedWidget?.name)
        let entry = WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
    }
    
    private func loadConfig(name: String?) -> WidgetConfig? {
        guard let name = name else { return nil }
        
        // Try UserDefaults first
        if let defaults = UserDefaults(suiteName: appGroupID),
           let data = defaults.data(forKey: "widgetConfigurations"),
           let configurations = try? decodeConfigurations(from: data),
           let config = configurations.first(where: { $0.name == name }) {
            return config
        }
        
        // Fallback: load from file
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.appendingPathComponent("configurations.json"),
           let data = try? Data(contentsOf: url),
           let configurations = try? decodeConfigurations(from: data),
           let config = configurations.first(where: { $0.name == name }) {
            return config
        }
        
        return nil
    }
    
    private func decodeConfigurations(from data: Data) throws -> [WidgetConfig] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WidgetConfig].self, from: data)
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
}
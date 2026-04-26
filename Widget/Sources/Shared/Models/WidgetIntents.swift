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
        // Explicit App Group check with diagnostic entity
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return [WidgetNameEntity(id: "Error", name: "Invalid App Group ID: \(appGroupID)")]
        }
        
        guard let data = sharedDefaults.data(forKey: "widgetConfigurations") else {
            // Data key doesn't exist - return empty (not an error, just no data)
            return []
        }
        
        do {
            let configurations = try JSONDecoder().decode([WidgetConfig].self, from: data)
            return configurations
                .filter { identifiers.contains($0.name) }
                .map { WidgetNameEntity(id: $0.name, name: $0.name) }
        } catch {
            return [WidgetNameEntity(id: "Error", name: "Decoding Error: \(error.localizedDescription)")]
        }
    }
    
    func suggestedEntities() async throws -> [WidgetNameEntity] {
        // Explicit App Group check with diagnostic entity
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return [WidgetNameEntity(id: "Error", name: "Invalid App Group ID: \(appGroupID)")]
        }
        
        // Check if data exists
        guard let data = sharedDefaults.data(forKey: "widgetConfigurations") else {
            // Key doesn't exist or is nil - might be empty app
            return [WidgetNameEntity(id: "No Data", name: "No Data in App Group")]
        }
        
        // Try to decode
        do {
            let configurations = try JSONDecoder().decode([WidgetConfig].self, from: data)
            
            // Check if array is empty
            if configurations.isEmpty {
                return [WidgetNameEntity(id: "Empty", name: "Empty Configurations")]
            }
            
            let entities = configurations.map { WidgetNameEntity(id: $0.name, name: $0.name) }
            return entities
        } catch {
            return [WidgetNameEntity(id: "Error", name: "Decoding Error: \(error.localizedDescription)")]
        }
    }
    
    func defaultResult() async -> WidgetNameEntity? {
        // Same logic as suggestedEntities() but return first item
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID),
              let data = sharedDefaults.data(forKey: "widgetConfigurations"),
              let configurations = try? JSONDecoder().decode([WidgetConfig].self, from: data),
              let firstConfig = configurations.first else {
            return nil
        }
        
        return WidgetNameEntity(id: firstConfig.name, name: firstConfig.name)
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
        
        // Explicit App Group check
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            print("[BroadcastProvider] Invalid App Group ID: \(appGroupID)")
            return nil
        }
        
        guard let data = sharedDefaults.data(forKey: "widgetConfigurations") else {
            print("[BroadcastProvider] No data for key 'widgetConfigurations'")
            return nil
        }
        
        do {
            let configurations = try JSONDecoder().decode([WidgetConfig].self, from: data)
            if let config = configurations.first(where: { $0.name == name }) {
                return config
            }
            print("[BroadcastProvider] Config not found: \(name)")
        } catch {
            print("[BroadcastProvider] Decoding error: \(error.localizedDescription)")
        }
        
        // Fallback: load from file
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.appendingPathComponent("configurations.json"),
           let data = try? Data(contentsOf: url),
           let configurations = try? JSONDecoder().decode([WidgetConfig].self, from: data),
           let config = configurations.first(where: { $0.name == name }) {
            return config
        }
        
        return nil
    }
}
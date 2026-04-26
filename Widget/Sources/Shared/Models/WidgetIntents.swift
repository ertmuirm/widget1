import AppIntents
import WidgetKit

// MARK: - Widget Name Entity for App Intents

/// AppEntity representing a widget configuration for selection in the Edit Widget menu
struct WidgetNameEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Widget")
    }
    
    static var defaultQuery: WidgetNameQuery { WidgetNameQuery() }
    
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
    typealias Entity = WidgetNameEntity
    
    private let appGroupID = StorageKeys.appGroupIdentifier
    
    func entities(for identifiers: [String]) async throws -> [WidgetNameEntity] {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return []
        }
        
        // Force synchronize
        sharedDefaults.synchronize()
        
        guard let data = sharedDefaults.data(forKey: "widgetConfigurations") else {
            return []
        }
        
        do {
            let configurations = try JSONDecoder().decode([WidgetConfig].self, from: data)
            return configurations
                .filter { identifiers.contains($0.name) }
                .map { WidgetNameEntity(id: $0.name, name: $0.name) }
        } catch {
            return []
        }
    }
    
    func suggestedEntities() async throws -> [WidgetNameEntity] {
        // Explicit App Group check with diagnostic entity
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return [WidgetNameEntity(id: "Error", name: "Invalid App Group ID: \(appGroupID)")]
        }
        
        // Force synchronize to get latest data
        sharedDefaults.synchronize()
        
        // Check if data exists
        guard let data = sharedDefaults.data(forKey: "widgetConfigurations") else {
            // Key doesn't exist or is nil - might be empty app
            // Return empty array instead of diagnostic entity to allow user to add widgets
            return []
        }
        
        // Try to decode
        do {
            let configurations = try JSONDecoder().decode([WidgetConfig].self, from: data)
            
            // Check if array is empty
            if configurations.isEmpty {
                return []
            }
            
            let entities = configurations.map { WidgetNameEntity(id: $0.name, name: $0.name) }
            return entities
        } catch {
            return []
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
    
    @Parameter(title: "Widget")
    var selectedWidget: WidgetNameEntity?
    
    init() {}
    
    init(selectedWidget: WidgetNameEntity?) {
        self.selectedWidget = selectedWidget
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
}

// MARK: - Timeline Provider

struct BroadcastProvider: AppIntentTimelineProvider {
    private let appGroupID: String
    
    init() {
        self.appGroupID = StorageKeys.appGroupIdentifier
    }
    
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
        return Timeline(entries: [entry], policy: .atEnd)
    }
    
    private func loadConfig(name: String?) -> WidgetConfig? {
        guard let name = name else { return nil }
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            return nil
        }
        
        // Force synchronize to get latest data
        sharedDefaults.synchronize()
        
        guard let data = sharedDefaults.data(forKey: "widgetConfigurations"),
              let configurations = try? JSONDecoder().decode([WidgetConfig].self, from: data),
              let config = configurations.first(where: { $0.name == name }) else {
            return nil
        }
        
        return config
    }
}
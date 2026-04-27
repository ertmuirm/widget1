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
// MARK: - Helper Functions

/// Get working UserDefaults with fallback
func getWorkingUserDefaults() -> UserDefaults? {
    let appGroupIDs = [
        "group.com.iosmirror.J3D2F4SMVD",
        "group.J3D2F4SMVD.com.iosmirror",
        "group.com.iosmirror"
    ]
    
    for id in appGroupIDs {
        if let defaults = UserDefaults(suiteName: id) {
            defaults.set("test", forKey: "_test_global")
            if defaults.string(forKey: "_test_global") == "test" {
                defaults.removeObject(forKey: "_test_global")
                return defaults
            }
        }
    }
    return UserDefaults.standard
}

struct WidgetNameQuery: EntityQuery {
    typealias Entity = WidgetNameEntity
    
    func entities(for identifiers: [String]) async throws -> [WidgetNameEntity] {
        print("[WidgetNameQuery.entities] Looking for: \(identifiers)")
        
        // Use App Group UserDefaults for widget extension
        guard let sharedDefaults = getWorkingUserDefaults(),
              let data = sharedDefaults.data(forKey: "widgetConfigurations") else {
            print("[WidgetNameQuery.entities] No data in UserDefaults for key 'widgetConfigurations'")
            return []
        }
        
        print("[WidgetNameQuery.entities] Found \(data.count) bytes in UserDefaults")
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let configurations = try decoder.decode([WidgetConfig].self, from: data)
            print("[WidgetNameQuery.entities] Decoded \(configurations.count) configs")
            return configurations
                .filter { identifiers.contains($0.name) }
                .map { WidgetNameEntity(id: $0.name, name: $0.name) }
        } catch {
            print("[WidgetNameQuery.entities] ERROR decoding: \(error)")
            return [WidgetNameEntity(id: "Error", name: "Decoding Error: \(error.localizedDescription)")]
        }
    }
    
    func suggestedEntities() async throws -> [WidgetNameEntity] {
        print("[WidgetNameQuery.suggestedEntities]")
        
        // Use App Group UserDefaults
        guard let sharedDefaults = getWorkingUserDefaults(),
              let data = sharedDefaults.data(forKey: "widgetConfigurations") else {
            print("[WidgetNameQuery.suggestedEntities] No data for key 'widgetConfigurations'")
            return [WidgetNameEntity(id: "No Data", name: "No Data in App Group")]
        }
        
        print("[WidgetNameQuery.suggestedEntities] Found \(data.count) bytes")
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let configurations = try decoder.decode([WidgetConfig].self, from: data)
            print("[WidgetNameQuery.suggestedEntities] Decoded \(configurations.count) configs")
            
            if configurations.isEmpty {
                return [WidgetNameEntity(id: "Empty", name: "Empty Configurations")]
            }
            
            return configurations.map { WidgetNameEntity(id: $0.name, name: $0.name) }
        } catch {
            print("[WidgetNameQuery.suggestedEntities] ERROR: \(error)")
            return [WidgetNameEntity(id: "Error", name: "Decoding Error: \(error.localizedDescription)")]
        }
    }
    
    func defaultResult() async -> WidgetNameEntity? {
        guard let sharedDefaults = getWorkingUserDefaults() else { return nil }
        guard let data = sharedDefaults.data(forKey: "widgetConfigurations"),
              let configurations = try? JSONDecoder().decode([WidgetConfig].self, from: data),
              let firstConfig = configurations.first else { return nil }
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
    
    
    init() {
        
    }
    
    func placeholder(in context: Context) -> WidgetEntry {
        print("[BroadcastProvider] placeholder called")
        return WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
    }

    func snapshot(for configuration: SelectWidgetIntent, in context: Context) async -> WidgetEntry {
        let configName = configuration.selectedWidget?.name
        print("[BroadcastProvider] snapshot called, selectedWidget: \(configName ?? "nil")")
        
        let config = loadConfig(name: configName)
        let finalConfig = config ?? WidgetConfig.defaultConfiguration
        
        print("[BroadcastProvider] Using config: \(finalConfig.name), items: \(finalConfig.items.count), size: \(finalConfig.size)")
        return WidgetEntry(date: Date(), configuration: finalConfig)
    }

    func timeline(for configuration: SelectWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let configName = configuration.selectedWidget?.name
        print("[BroadcastProvider] timeline called, selectedWidget: \(configName ?? "nil")")
        
        let config = loadConfig(name: configName)
        let finalConfig = config ?? WidgetConfig.defaultConfiguration
        
        print("[BroadcastProvider] Timeline config: \(finalConfig.name), items: \(finalConfig.items.count), size: \(finalConfig.size)")
        
        // Create timeline with entries every 15 minutes
        let entries = (0..<4).map { offset in
            WidgetEntry(date: Date().addingTimeInterval(TimeInterval(offset * 900)), configuration: finalConfig)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
    
    private func loadConfig(name: String?) -> WidgetConfig? {
        guard let name = name else { return nil }
        guard let config = SharedStorage.shared.getConfig(named: name) else {
            print("[BroadcastProvider] Config not found: " + name)
            return nil
        }
        print("[BroadcastProvider] Found: " + name + " items: " + String(config.items.count))
        return config
    }
}

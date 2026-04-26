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
        print("[WidgetNameQuery.entities] Looking for identifiers: \(identifiers)")
        
        // Try UserDefaults first
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.synchronize()
            
            if let data = sharedDefaults.data(forKey: "widgetConfigurations") {
                print("[WidgetNameQuery.entities] Found data in UserDefaults, size: \(data.count) bytes")
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let configurations = try decoder.decode([WidgetConfig].self, from: data)
                    print("[WidgetNameQuery.entities] Decoded \(configurations.count) configs from UserDefaults")
                    let filtered = configurations.filter { identifiers.contains($0.name) }
                    print("[WidgetNameQuery.entities] Filtered to \(filtered.count) matching configs")
                    return filtered.map { WidgetNameEntity(id: $0.name, name: $0.name) }
                } catch {
                    print("[WidgetNameQuery.entities] ERROR decoding UserDefaults: \(error)")
                }
            } else {
                print("[WidgetNameQuery.entities] No data in UserDefaults for key 'widgetConfigurations'")
            }
        } else {
            print("[WidgetNameQuery.entities] ERROR: Could not access App Group UserDefaults")
        }
        
        // Fallback to file-based storage
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("configurations.json")
            print("[WidgetNameQuery.entities] Checking file: \(fileURL.path)")
            if let data = try? Data(contentsOf: fileURL) {
                print("[WidgetNameQuery.entities] Found data in file, size: \(data.count) bytes")
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let configurations = try decoder.decode([WidgetConfig].self, from: data)
                    print("[WidgetNameQuery.entities] Decoded \(configurations.count) configs from file")
                    let filtered = configurations.filter { identifiers.contains($0.name) }
                    print("[WidgetNameQuery.entities] Filtered to \(filtered.count) matching configs")
                    return filtered.map { WidgetNameEntity(id: $0.name, name: $0.name) }
                } catch {
                    print("[WidgetNameQuery.entities] ERROR decoding file: \(error)")
                }
            } else {
                print("[WidgetNameQuery.entities] No data in file")
            }
        }
        
        print("[WidgetNameQuery.entities] Returning empty array")
        return []
    }
    
    func suggestedEntities() async throws -> [WidgetNameEntity] {
        var debugInfo = ""
        
        // Try UserDefaults first
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.synchronize()
            debugInfo += "[suggestedEntities] UserDefaults accessed\n"
            
            if let data = sharedDefaults.data(forKey: "widgetConfigurations") {
                debugInfo += "[suggestedEntities] Found \(data.count) bytes in UserDefaults\n"
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let configurations = try decoder.decode([WidgetConfig].self, from: data)
                    debugInfo += "[suggestedEntities] Decoded \(configurations.count) configs from UserDefaults\n"
                    if !configurations.isEmpty {
                        writeDebugLog(debugInfo)
                        return configurations.map { WidgetNameEntity(id: $0.name, name: $0.name) }
                    }
                } catch {
                    debugInfo += "[suggestedEntities] ERROR decoding UserDefaults: \(error)\n"
                }
            } else {
                debugInfo += "[suggestedEntities] No data in UserDefaults for 'widgetConfigurations'\n"
            }
        } else {
            debugInfo += "[suggestedEntities] ERROR: Could not access App Group UserDefaults\n"
        }
        
        // Fallback to file-based storage
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("configurations.json")
            debugInfo += "[suggestedEntities] Checking file: \(fileURL.path)\n"
            
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: containerURL.path, isDirectory: &isDir)
            debugInfo += "[suggestedEntities] Container exists: \(exists), isDir: \(isDir.boolValue)\n"
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let data = try? Data(contentsOf: fileURL) {
                    debugInfo += "[suggestedEntities] Found \(data.count) bytes in file\n"
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let configurations = try decoder.decode([WidgetConfig].self, from: data)
                        debugInfo += "[suggestedEntities] Decoded \(configurations.count) configs from file\n"
                        if !configurations.isEmpty {
                            writeDebugLog(debugInfo)
                            return configurations.map { WidgetNameEntity(id: $0.name, name: $0.name) }
                        }
                    } catch {
                        debugInfo += "[suggestedEntities] ERROR decoding file: \(error)\n"
                    }
                }
            } else {
                debugInfo += "[suggestedEntities] File does not exist at: \(fileURL.path)\n"
            }
        }
        
        debugInfo += "[suggestedEntities] No configurations found, returning empty array\n"
        writeDebugLog(debugInfo)
        return []
    }
    
    private func writeDebugLog(_ message: String) {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let logFile = containerURL.appendingPathComponent("debug.log")
            let entry = "[\(ISO8601DateFormatter().string(from: Date()))] [WidgetQuery] \(message)\n"
            if let data = entry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let handle = try? FileHandle(forWritingTo: logFile) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: logFile)
                }
            }
        }
    }
    
    func defaultResult() async -> WidgetNameEntity? {
        // Try UserDefaults first
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.synchronize()
            
            if let data = sharedDefaults.data(forKey: "widgetConfigurations") {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let configurations = try? decoder.decode([WidgetConfig].self, from: data),
                   let firstConfig = configurations.first {
                    return WidgetNameEntity(id: firstConfig.name, name: firstConfig.name)
                }
            }
        }
        
        // Fallback to file-based storage
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
           let data = try? Data(contentsOf: containerURL.appendingPathComponent("configurations.json")) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let configurations = try? decoder.decode([WidgetConfig].self, from: data),
               let firstConfig = configurations.first {
                return WidgetNameEntity(id: firstConfig.name, name: firstConfig.name)
            }
        }
        
        return nil
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
        
        // Try UserDefaults first
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.synchronize()
            
            if let data = sharedDefaults.data(forKey: "widgetConfigurations") {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let configurations = try? decoder.decode([WidgetConfig].self, from: data),
                   let config = configurations.first(where: { $0.name == name }) {
                    print("[BroadcastProvider] Found config '\(name)' in UserDefaults")
                    return config
                }
            }
        }
        
        // Fallback to file-based storage
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("configurations.json")
            if let data = try? Data(contentsOf: fileURL) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let configurations = try? decoder.decode([WidgetConfig].self, from: data),
                   let config = configurations.first(where: { $0.name == name }) {
                    print("[BroadcastProvider] Found config '\(name)' in file")
                    return config
                }
            }
        }
        
        print("[BroadcastProvider] Config '\(name)' not found")
        return nil
    }
}
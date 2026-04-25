import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Selection Intent

struct SelectWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget"
    static var description = IntentDescription("Select which widget to display")
    
    @Parameter(title: "Widget", optionsProvider: WidgetOptionsProvider())
    var widgetName: String?
    
    init() {}
    init(widgetName: String?) { self.widgetName = widgetName }
}

// MARK: - Dynamic Options Provider

struct WidgetOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.iosmirror")?.appendingPathComponent("configurations.json"),
              let data = try? Data(contentsOf: url),
              let configs = try? JSONDecoder().decode([WidgetConfig].self, from: data) else { return [] }
        return configs.map { $0.name }
    }
    
    func defaultResult() async -> String? {
        results().first
    }
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
        let config = loadConfiguration(name: configuration.widgetName)
        return WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
    }
    
    func timeline(for configuration: SelectWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let config = loadConfiguration(name: configuration.widgetName)
        let entry = WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
    }
    
    private func loadConfiguration(name: String?) -> WidgetConfig? {
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

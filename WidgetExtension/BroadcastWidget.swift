import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Configuration Intent

struct WidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget"
    static var description = IntentDescription("Select which widget to display")
    
    @Parameter(title: "Widget", optionsProvider: WidgetOptionsProvider())
    var widgetName: String?
    
    init() {}
    
    init(widgetName: String?) {
        self.widgetName = widgetName
    }
}

// MARK: - Dynamic Options Provider

struct WidgetOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        loadConfigurations().map { $0.name }
    }
    
    func defaultResult() async -> String? {
        loadConfigurations().first?.name
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
        } catch { return [] }
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
        .description("Create custom widgets")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular, .accessoryInline, .accessoryRectangular])
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
        let config = loadConfiguration(name: configuration.widgetName)
        return WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
    }

    func timeline(for configuration: WidgetConfigurationIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let config = loadConfiguration(name: configuration.widgetName)
        let entry = WidgetEntry(date: Date(), configuration: config ?? WidgetConfig.defaultConfiguration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
    }
    
    private func loadConfiguration(name: String?) -> WidgetConfig? {
        guard let name = name,
              let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.iosmirror")?.appendingPathComponent("configurations.json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let configs = try JSONDecoder().decode([WidgetConfig].self, from: data)
            return configs.first { $0.name == name }
        } catch { return nil }
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
}

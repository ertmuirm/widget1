import WidgetKit
import SwiftUI

struct BroadcastWidget: Widget {
    let kind: String = "BroadcastExtension"

    var body: some WidgetConfig {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Widget")
        .description("Create custom widgets with customizable actions")
        .supportedFamilies([
            // Home Screen families
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            // Lock Screen families
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let configurations = loadConfigurations()
        
        if configurations.isEmpty {
            let entry = WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
            completion(timeline)
        } else {
            var entries: [WidgetEntry] = []
            for config in configurations {
                let entry = WidgetEntry(date: Date(), configuration: config)
                entries.append(entry)
            }
            let timeline = Timeline(entries: entries, policy: .after(Date().addingTimeInterval(3600)))
            completion(timeline)
        }
    }
    
    private func loadConfigurations() -> [WidgetConfig] {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.iosmirror"
        )?.appendingPathComponent("configurations.json") else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let configurations = try JSONDecoder().decode([WidgetConfig].self, from: data)
            return configurations
        } catch {
            return []
        }
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
}

import WidgetKit
import SwiftUI

struct BroadcastWidget: Widget {
    let kind: String = "BroadcastExtension"

    var body: some WidgetConfiguration {
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
        WidgetEntry(date: Date(), configuration: placeholderConfiguration())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(date: Date(), configuration: placeholderConfiguration())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let configurations = loadConfigurations()
        
        // Create timeline entries for each configuration
        var entries: [WidgetEntry] = []
        
        if configurations.isEmpty {
            // No configurations - show placeholder
            let entry = WidgetEntry(date: Date(), configuration: placeholderConfiguration())
            entries.append(entry)
        } else {
            // Add entries for each configuration
            for config in configurations {
                let entry = WidgetEntry(date: Date(), configuration: config)
                entries.append(entry)
            }
        }
        
        // Refresh every hour
        let refreshDate = Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func placeholderConfiguration() -> WidgetConfiguration {
        WidgetConfiguration(
            name: "Sample Widget",
            size: .systemMedium,
            items: [
                WidgetItem(
                    displayType: .icon,
                    sfSymbolName: "star.fill",
                    foregroundColor: CodableColor(.white),
                    backgroundColor: CodableColor(.clear)
                )
            ],
            backgroundColor: CodableColor(.black)
        )
    }
    
    private func loadConfigurations() -> [WidgetConfiguration] {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.iosmirror"
        )?.appendingPathComponent("configurations.json") else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let configurations = try JSONDecoder().decode([WidgetConfiguration].self, from: data)
            return configurations
        } catch {
            return []
        }
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfiguration
}
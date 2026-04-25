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

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = WidgetEntry(date: Date(), configuration: WidgetConfig.defaultConfiguration)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfig
}

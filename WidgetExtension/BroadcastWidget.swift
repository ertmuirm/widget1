import WidgetKit
import SwiftUI
import AppIntents

// Use shared AppEntity and Intent from WidgetSources
// Note: WidgetConfig must be accessible to both targets

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

// Use BroadcastProvider from shared WidgetSources
// The SelectWidgetIntent and WidgetNameEntity are defined in WidgetSources
// This file just provides the entry point

// MARK: - Widget Entry

// Use WidgetEntry from shared WidgetSources

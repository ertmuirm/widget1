import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Small Widget (1×1)

struct BroadcastSmallWidget: Widget {
    let kind = "BroadcastSmall"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectSmallWidgetIntent.self,
            provider: SmallBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Small Widget")
        .description("A 1×1 customizable widget")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium Widget (3×3)

struct BroadcastMediumWidget: Widget {
    let kind = "BroadcastMedium"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectMediumWidgetIntent.self,
            provider: MediumBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Medium Widget")
        .description("A 3×3 customizable widget")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Large Widget (6×3)

struct BroadcastLargeWidget: Widget {
    let kind = "BroadcastLarge"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectLargeWidgetIntent.self,
            provider: LargeBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Large Widget")
        .description("A 6×3 customizable widget")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Extra Large Widget (6×6)

struct BroadcastExtraLargeWidget: Widget {
    let kind = "BroadcastExtraLarge"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectExtraLargeWidgetIntent.self,
            provider: ExtraLargeBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Extra Large Widget")
        .description("A 6×6 customizable widget")
        .supportedFamilies([.systemExtraLarge])
    }
}

// MARK: - Lock Screen Widget

struct BroadcastLockWidget: Widget {
    let kind = "BroadcastLock"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectLockWidgetIntent.self,
            provider: LockBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Lock Screen Widget")
        .description("A customizable lock screen widget")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    BroadcastSmallWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfig(
        name: "Preview",
        size: .systemSmall,
        items: [WidgetItem(displayType: .icon, sfSymbolName: "star.fill")]
    ))
}

#Preview("Medium", as: .systemMedium) {
    BroadcastMediumWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfig(
        name: "Preview",
        size: .systemMedium,
        items: [
            WidgetItem(displayType: .icon, sfSymbolName: "star.fill"),
            WidgetItem(displayType: .text, customText: "Hello")
        ]
    ))
}

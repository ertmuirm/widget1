import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Small Widget — home screen Small (3×3 grid, systemSmall)

struct BroadcastSmallWidget: Widget {
    let kind = "BroadcastSmall"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectSmallWidgetIntent.self,
            provider: SmallBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    entry.configuration.backgroundColor.swiftUIColor
                        .opacity(entry.configuration.backgroundOpacity)
                }
        }
        .configurationDisplayName("Small Widget")
        .description("A 3×3 customizable widget")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium Widget — home screen Medium (6×3 grid, systemMedium)

struct BroadcastMediumWidget: Widget {
    let kind = "BroadcastMedium"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectMediumWidgetIntent.self,
            provider: MediumBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    entry.configuration.backgroundColor.swiftUIColor
                        .opacity(entry.configuration.backgroundOpacity)
                }
        }
        .configurationDisplayName("Medium Widget")
        .description("A 6×3 customizable widget")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Large Widget — home screen Large (6×6 grid, systemLarge)

struct BroadcastLargeWidget: Widget {
    let kind = "BroadcastLarge"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectLargeWidgetIntent.self,
            provider: LargeBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    entry.configuration.backgroundColor.swiftUIColor
                        .opacity(entry.configuration.backgroundOpacity)
                }
        }
        .configurationDisplayName("Large Widget")
        .description("A 6×6 customizable widget")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Lock Screen Widget (accessory families only)

struct BroadcastLockWidget: Widget {
    let kind = "BroadcastLock"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectLockWidgetIntent.self,
            provider: LockBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Lock Screen Widget")
        .description("A customizable lock screen widget")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

// MARK: - Clock Widget (2x2 medium for time display)

struct BroadcastClockWidget: Widget {
    let kind = "BroadcastClock"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectClockWidgetIntent.self,
            provider: ClockBroadcastProvider()
        ) { entry in
            ClockWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Clock Widget")
        .description("Displays time digits with configurable tap actions")
        .supportedFamilies([.systemMedium])
        .containerBackgroundRemovable(true)
    }
}

// MARK: - Code Widget (QR slideshow)

struct BroadcastImageWidget: Widget {
    let kind = "BroadcastImage"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectImageWidgetIntent.self,
            provider: ImageBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.white }
        }
        .configurationDisplayName("Code Widget")
        .description("Display QR codes on your home screen")
        .supportedFamilies([.systemSmall])
        // Prevent iOS 26 Clear/Liquid Glass mode from stripping the white background,
        // which would make the black-on-white QR code invisible.
        .containerBackgroundRemovable(false)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    BroadcastSmallWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfig(
        name: "Preview",
        size: .systemSmall,
        items: (0..<9).map { _ in WidgetItem(displayType: .icon, sfSymbolName: "star.fill") }
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

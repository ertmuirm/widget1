import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Rendering-mode-aware background

private struct WidgetBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let color: Color
    let opacity: Double

    var body: some View {
        if renderingMode == .fullColor && !reduceTransparency {
            color.opacity(opacity)
        } else {
            Color.secondary.opacity(0.1)
        }
    }
}

// MARK: - Checkerboard (preview transparency aid)

/// Used in Xcode previews as a ZStack layer behind WidgetEntryView so any
/// transparent region of the widget shows up as tiles rather than solid black.
/// Use darkMode: true to simulate dark wallpaper / dark-mode scenarios.
struct CheckerboardView: View {
    var tileSize: CGFloat = 8
    var darkMode: Bool = false

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width  / tileSize))
            let rows = Int(ceil(size.height / tileSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let primary = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    let color: Color = darkMode
                        ? (primary ? Color(white: 0.22) : Color(white: 0.12))
                        : (primary ? .white              : Color(white: 0.78))
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}

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
                    WidgetBackground(
                        color: entry.configuration.backgroundColor.swiftUIColor,
                        opacity: entry.configuration.backgroundOpacity
                    )
                }
        }
        .configurationDisplayName("Small Widget")
        .description("A 3×3 customizable widget")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
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
                    WidgetBackground(
                        color: entry.configuration.backgroundColor.swiftUIColor,
                        opacity: entry.configuration.backgroundOpacity
                    )
                }
        }
        .configurationDisplayName("Medium Widget")
        .description("A 6×3 customizable widget")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
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
                    WidgetBackground(
                        color: entry.configuration.backgroundColor.swiftUIColor,
                        opacity: entry.configuration.backgroundOpacity
                    )
                }
        }
        .configurationDisplayName("Large Widget")
        .description("A 6×6 customizable widget")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
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
        .contentMarginsDisabled()
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
        // No contentMarginsDisabled — the system margins are intentional here;
        // WidgetEntryView uses .padding(-10) to fill edge-to-edge within them.
        // Prevent Clear/Liquid Glass mode from stripping the white background —
        // a transparent surface would make the black QR code invisible.
        .containerBackgroundRemovable(false)
    }
}

// MARK: - Clock Widget

struct BroadcastClockWidget: Widget {
    let kind = "BroadcastClock"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectClockWidgetIntent.self,
            provider: ClockBroadcastProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
                // Empty body — no background view at all. Combined with
                // containerBackgroundRemovable(true) this gives the system
                // full permission to render nothing behind the widget in
                // iOS 26 Clear Mode.
                .containerBackground(for: .widget) { }
        }
        .configurationDisplayName("Clock Widget")
        .description("Display hour or minute digits")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

// MARK: - Clock checkerboard preview helpers

/// Wraps the clock in a ZStack with a checkerboard so transparent regions are
/// immediately visible in the Xcode canvas — checkerboard is rendered as widget
/// content, not containerBackground, so it always appears regardless of how the
/// preview host handles containerBackground.
private struct ClockCheckerboardPreview: Widget {
    let darkMode: Bool

    init(darkMode: Bool = false) { self.darkMode = darkMode }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: darkMode ? "ClockCheckDark" : "ClockCheckLight",
            intent: SelectClockWidgetIntent.self,
            provider: ClockBroadcastProvider()
        ) { entry in
            ZStack {
                CheckerboardView(darkMode: darkMode)
                WidgetEntryView(entry: entry)
            }
            .containerBackground(for: .widget) { }
        }
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

private func clockPreviewEntry() -> WidgetEntry {
    WidgetEntry(
        date: .now,
        configuration: WidgetConfig(
            name: "Clock",
            size: .systemSmall,
            widgetKind: .clock,
            clockDigitPosition: .hour,
            clockFontSize: 80
        )
    )
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

#Preview("Clock", as: .systemSmall) {
    BroadcastClockWidget()
} timeline: {
    clockPreviewEntry()
}

// Checkerboard previews — transparent pixels show as tiles, opaque pixels hide them.
// Light board = simulates light wallpaper / Default appearance.
// Dark board  = simulates dark wallpaper / Dark Mode.

#Preview("Clock – light bg check", as: .systemSmall) {
    ClockCheckerboardPreview(darkMode: false)
} timeline: {
    clockPreviewEntry()
}

#Preview("Clock – dark bg check", as: .systemSmall) {
    ClockCheckerboardPreview(darkMode: true)
} timeline: {
    clockPreviewEntry()
}

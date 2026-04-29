import SwiftUI
import WidgetKit

/// Main widget entry view that renders based on widget family
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: WidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            homeScreenWidget
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            lockScreenWidget
        default:
            homeScreenWidget
        }
    }

    // MARK: - Home Screen

    @ViewBuilder
    private var homeScreenWidget: some View {
        ZStack {
            entry.configuration.backgroundColor.swiftUIColor
                .opacity(entry.configuration.backgroundOpacity)

            if entry.configuration.items.isEmpty {
                emptyView
            } else {
                itemsGrid
            }

            #if DEBUG
            VStack(alignment: .leading, spacing: 1) {
                Text("cfg:\(entry.configuration.name) items:\(entry.configuration.items.count)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.yellow)
                Text(entry.debugInfo.components(separatedBy: "\n").prefix(3).joined(separator: " | "))
                    .font(.system(size: 6, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .lineLimit(2)
                Spacer()
            }
            .padding(4)
            #endif
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.title2)
            Text("Add items")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var itemsGrid: some View {
        switch widgetFamily {
        case .systemSmall:      smallGrid
        case .systemMedium:     mediumGrid
        case .systemLarge:      largeGrid
        case .systemExtraLarge: extraLargeGrid
        default:                mediumGrid
        }
    }

    // MARK: - Grid layouts

    // Small: 3 columns × 3 rows = 9 items (iOS systemSmall)
    private var smallGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(9).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemSmall)
            }
        }
        .padding(4)
    }

    // Medium: 6 columns × 3 rows = 18 items (iOS systemMedium)
    private var mediumGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(18).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemMedium)
            }
        }
        .padding(4)
    }

    // Large: 6 columns × 6 rows = 36 items (iOS systemLarge)
    private var largeGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(36).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemLarge)
            }
        }
        .padding(4)
    }

    // Extra large treated identically to large
    private var extraLargeGrid: some View {
        largeGrid
    }

    // MARK: - Cell with optional URL link for tap action

    @ViewBuilder
    private func itemCell(_ item: WidgetItem, size: WidgetSize) -> some View {
        if let action = item.action, action.type == .urlScheme,
           let url = URL(string: action.payload), !action.payload.isEmpty {
            Link(destination: url) {
                ItemView(item: item, widgetSize: size, showLabel: entry.showItemLabels)
            }
        } else {
            ItemView(item: item, widgetSize: size, showLabel: entry.showItemLabels)
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private var lockScreenWidget: some View {
        switch widgetFamily {
        case .accessoryCircular:    accessoryCircularWidget
        case .accessoryInline:      accessoryInlineWidget
        case .accessoryRectangular: accessoryRectangularWidget
        default:                    accessoryCircularWidget
        }
    }

    @ViewBuilder
    private var accessoryCircularWidget: some View {
        if let item = entry.configuration.items.first {
            if item.displayType == .icon, let symbol = item.sfSymbolName {
                Image(systemName: symbol)
                    .font(.system(size: 20))
            } else {
                Text(item.customText?.prefix(2) ?? "")
                    .font(.system(size: 14, weight: .medium))
            }
        } else {
            Image(systemName: "questionmark")
        }
    }

    @ViewBuilder
    private var accessoryInlineWidget: some View {
        if let item = entry.configuration.items.first {
            if item.displayType == .icon, let symbol = item.sfSymbolName {
                HStack(spacing: 2) {
                    Image(systemName: symbol)
                    if let text = item.customText, !text.isEmpty {
                        Text(text)
                    }
                }
            } else {
                Text(item.customText ?? "")
            }
        } else {
            Text("Widget")
        }
    }

    @ViewBuilder
    private var accessoryRectangularWidget: some View {
        HStack(spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(6).enumerated()), id: \.element.id) { _, item in
                LockScreenItemView(item: item)
            }
        }
    }
}

// MARK: - Item View

struct ItemView: View {
    let item: WidgetItem
    let widgetSize: WidgetSize
    let showLabel: Bool

    private var symbolSize: CGFloat {
        switch widgetSize {
        case .systemSmall:      return 14  // 3×3 grid — each cell is small
        case .systemMedium:     return 10  // 6×3 grid
        case .systemLarge:      return 10  // 6×6 grid
        case .systemExtraLarge: return 10
        }
    }

    var body: some View {
        ZStack {
            item.backgroundColor.swiftUIColor
                .opacity(item.backgroundOpacity)

            if item.displayType == .icon {
                VStack(spacing: 2) {
                    if let symbol = item.sfSymbolName {
                        Image(systemName: symbol)
                            .font(.system(size: symbolSize))
                            .foregroundStyle(item.foregroundColor.swiftUIColor)
                    }
                    // Label below icon when showLabel is enabled
                    if showLabel, let text = item.customText, !text.isEmpty {
                        Text(text)
                            .font(.system(size: max(symbolSize * 0.4, 6)))
                            .foregroundStyle(item.foregroundColor.swiftUIColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            } else {
                Text(item.customText ?? "")
                    .font(.system(size: CGFloat(item.fontSize)))
                    .foregroundStyle(item.foregroundColor.swiftUIColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lock Screen Item View

struct LockScreenItemView: View {
    let item: WidgetItem

    var body: some View {
        ZStack {
            if item.displayType == .icon {
                if let symbol = item.sfSymbolName {
                    Image(systemName: symbol)
                        .font(.system(size: 12))
                }
            } else {
                Text(item.customText?.prefix(1) ?? "")
                    .font(.system(size: 10))
            }
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    BroadcastSmallWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfig(
        name: "Preview",
        size: .systemSmall,
        items: [WidgetItem(displayType: .icon, sfSymbolName: "star.fill", customText: "Star")]
    ))
}

#Preview("Medium", as: .systemMedium) {
    BroadcastMediumWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfig(
        name: "Preview",
        size: .systemMedium,
        items: [
            WidgetItem(displayType: .icon, sfSymbolName: "star.fill", customText: "Star"),
            WidgetItem(displayType: .text, customText: "Hello")
        ]
    ))
}

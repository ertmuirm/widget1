import SwiftUI
import WidgetKit

/// Main widget entry view that renders based on configuration
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: WidgetEntry

    var body: some View {
        // Route to appropriate renderer based on widget family
        switch widgetFamily {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            homeScreenWidget
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            lockScreenWidget
        default:
            homeScreenWidget // fallback
        }
    }
    
    // MARK: - Home Screen Widgets
    
    @ViewBuilder
    private var homeScreenWidget: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                entry.configuration.backgroundColor.swiftUIColor
                    .opacity(entry.configuration.backgroundOpacity)
                
                // Items grid
                if entry.configuration.items.isEmpty {
                    emptyView
                } else {
                    itemsGrid(in: geometry.size)
                }
            }
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
    private func itemsGrid(in size: CGSize) -> some View {
        let config = entry.configuration
        
        switch config.size {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        case .systemExtraLarge:
            extraLargeWidget
        }
    }
    
    // MARK: - Lock Screen Widgets
    
    @ViewBuilder
    private var lockScreenWidget: some View {
        switch widgetFamily {
        case .accessoryCircular:
            accessoryCircularWidget
        case .accessoryInline:
            accessoryInlineWidget
        case .accessoryRectangular:
            accessoryRectangularWidget
        default:
            accessoryCircularWidget
        }
    }
    
    @ViewBuilder
    private var accessoryCircularWidget: some View {
        if let item = entry.configuration.items.first {
            if item.displayType == .icon, let symbolName = item.sfSymbolName {
                Image(systemName: symbolName)
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
            if item.displayType == .icon, let symbolName = item.sfSymbolName {
                HStack(spacing: 2) {
                    Image(systemName: symbolName)
                    Text(item.customText ?? "")
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
    
    // MARK: - Small Widget (1x1)
    
    @ViewBuilder
    private var smallWidget: some View {
        if let item = entry.configuration.items.first {
            ItemView(item: item, size: .systemSmall)
        }
    }
    
    // MARK: - Medium Widget (3x3)
    
    @ViewBuilder
    private var mediumWidget: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
        
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(9).enumerated()), id: \.element.id) { _, item in
                ItemView(item: item, size: .systemMedium)
            }
        }
        .padding(4)
    }
    
    // MARK: - Large Widget (6x3)
    
    @ViewBuilder
    private var largeWidget: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)
        
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(18).enumerated()), id: \.element.id) { _, item in
                ItemView(item: item, size: .systemLarge)
            }
        }
        .padding(4)
    }
    
    // MARK: - Extra Large Widget (6x6)
    
    @ViewBuilder
    private var extraLargeWidget: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)
        
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(36).enumerated()), id: \.element.id) { _, item in
                ItemView(item: item, size: .systemExtraLarge)
            }
        }
        .padding(4)
    }
}

// MARK: - Item View

struct ItemView: View {
    let item: WidgetItem
    let size: WidgetSize
    
    private var itemSize: CGFloat {
        switch size {
        case .systemSmall: return 60
        case .systemMedium: return 30
        case .systemLarge: return 15
        case .systemExtraLarge: return 15
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            item.backgroundColor.swiftUIColor
                .opacity(item.backgroundOpacity)
            
            // Content
            if item.displayType == .icon {
                if let symbolName = item.sfSymbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: itemSize * 0.5))
                        .foregroundStyle(item.foregroundColor.swiftUIColor)
                }
            } else {
                Text(item.customText ?? "")
                    .font(.system(size: itemSize * 0.3))
                    .foregroundStyle(item.foregroundColor.swiftUIColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
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
                if let symbolName = item.sfSymbolName {
                    Image(systemName: symbolName)
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

#Preview(as: .systemSmall) {
    BroadcastWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfiguration(
        name: "Test",
        size: .systemSmall,
        items: [WidgetItem(displayType: .icon, sfSymbolName: "star.fill")]
    ))
}

#Preview(as: .systemMedium) {
    BroadcastWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfiguration(
        name: "Test",
        size: .systemMedium,
        items: [
            WidgetItem(displayType: .icon, sfSymbolName: "star.fill"),
            WidgetItem(displayType: .text, customText: "A")
        ]
    ))
}
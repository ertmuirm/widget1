import SwiftUI
import WidgetKit
import AppIntents

/// Main widget entry view that renders based on widget family
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: WidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            if entry.configuration.widgetKind == .imageSlideshow {
                imageSlideshowWidget
            } else {
                homeScreenWidget
            }
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            lockScreenWidget
        default:
            homeScreenWidget
        }
    }

    // MARK: - Home Screen (grid)

    @ViewBuilder
    private var homeScreenWidget: some View {
        ZStack {
            if entry.configuration.items.isEmpty {
                emptyView
            } else {
                itemsGrid
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

    private var smallGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(9).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemSmall)
            }
        }
        .padding(4)
    }

    private var mediumGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(18).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemMedium)
            }
        }
        .padding(4)
    }

    private var largeGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(entry.configuration.items.prefix(36).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemLarge)
            }
        }
        .padding(4)
    }

    private var extraLargeGrid: some View { largeGrid }

    // MARK: - Cell with optional URL link

    @ViewBuilder
    private func itemCell(_ item: WidgetItem, size: WidgetSize) -> some View {
        if let url = resolveItemURL(item) {
            Link(destination: url) {
                ItemView(item: item, widgetSize: size, showLabel: entry.showItemLabels)
            }
        } else {
            ItemView(item: item, widgetSize: size, showLabel: entry.showItemLabels)
        }
    }

    // MARK: - Image Slideshow

    @ViewBuilder
    private var imageSlideshowWidget: some View {
        let slides = entry.configuration.slides ?? []
        let rawIndex = entry.configuration.currentSlideIndex ?? 0
        let index = slides.isEmpty ? 0 : min(rawIndex, slides.count - 1)
        let actionURL = entry.configuration.items.first.flatMap { resolveItemURL($0) }
        let hasNavigation = slides.count > 1
        let hasAction = actionURL != nil

        ZStack {
            if slides.isEmpty {
                Color.black
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Add Images")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                let slide = slides[index]
                if let image = SharedStorage.shared.loadWidgetImage(filename: slide.filename) {
                    GeometryReader { geo in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(CGFloat(slide.scale))
                            .offset(
                                x: CGFloat(slide.offsetX) * geo.size.width,
                                y: CGFloat(slide.offsetY) * geo.size.height
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    Color.gray.opacity(0.3)
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }

                // Three-zone tap overlay: left third (prev), center (action), right third (next)
                if hasNavigation || hasAction {
                    HStack(spacing: 0) {
                        // Left third — previous slide
                        Group {
                            if hasNavigation {
                                Button(intent: AdvanceImageIntent(
                                    widgetID: entry.configuration.id.uuidString, forward: false)) {
                                    Color.clear
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())

                        // Center third — configured action
                        Group {
                            if let url = actionURL {
                                Link(destination: url) { Color.clear }
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())

                        // Right third — next slide
                        Group {
                            if hasNavigation {
                                Button(intent: AdvanceImageIntent(
                                    widgetID: entry.configuration.id.uuidString, forward: true)) {
                                    Color.clear
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private var lockScreenWidget: some View {
        let actionURL = entry.configuration.items.first.flatMap { resolveItemURL($0) }

        Group {
            switch widgetFamily {
            case .accessoryCircular:    accessoryCircularWidget
            case .accessoryInline:      accessoryInlineWidget
            case .accessoryRectangular: accessoryRectangularWidget
            default:                    accessoryCircularWidget
            }
        }
        .widgetURL(actionURL)
    }

    @ViewBuilder
    private var accessoryCircularWidget: some View {
        if let item = entry.configuration.items.first {
            if item.displayType == .image, let filename = item.customImageFilename,
               let image = SharedStorage.shared.loadWidgetImage(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else if item.displayType == .icon, let symbol = item.sfSymbolName {
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
        case .systemSmall:      return 14
        case .systemMedium:     return 10
        case .systemLarge:      return 10
        case .systemExtraLarge: return 10
        }
    }

    var body: some View {
        ZStack {
            item.backgroundColor.swiftUIColor
                .opacity(item.backgroundOpacity)

            if item.displayType == .image, let filename = item.customImageFilename,
               let image = SharedStorage.shared.loadWidgetImage(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if item.displayType == .icon {
                VStack(spacing: 2) {
                    if let symbol = item.sfSymbolName {
                        Image(systemName: symbol)
                            .font(.system(size: symbolSize))
                            .foregroundStyle(item.foregroundColor.swiftUIColor)
                    }
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
            if item.displayType == .image, let filename = item.customImageFilename,
               let image = SharedStorage.shared.loadWidgetImage(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else if item.displayType == .icon {
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

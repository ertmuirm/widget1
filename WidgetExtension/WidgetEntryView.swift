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
            // Background NoOp covers padding and gap areas so they never open the app
            Button(intent: NoOpIntent()) { Color.clear }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .buttonStyle(.plain)

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
        let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
        return LazyVGrid(columns: columns, spacing: 1) {
            ForEach(Array(entry.configuration.items.prefix(9).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemSmall)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(-10)
    }

    private var mediumGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 6)
        return LazyVGrid(columns: columns, spacing: 1) {
            ForEach(Array(entry.configuration.items.prefix(18).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemMedium)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(-10)
    }

    private var largeGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 6)
        return LazyVGrid(columns: columns, spacing: 1) {
            ForEach(Array(entry.configuration.items.prefix(36).enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: .systemLarge)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(-10)
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
            // No action — plain view. The background NoOpIntent button (in homeScreenWidget)
            // handles dead-area taps. Wrapping every no-action item in Button(intent:) would
            // exceed WidgetKit's interactive-element budget and break rendering for multi-row grids.
            ItemView(item: item, widgetSize: size, showLabel: entry.showItemLabels)
        }
    }

    // MARK: - Image Slideshow

    @ViewBuilder
    private var imageSlideshowWidget: some View {
        let slides = entry.configuration.slides ?? []
        let rawIndex = entry.configuration.currentSlideIndex ?? 0
        let index = slides.isEmpty ? 0 : min(rawIndex, slides.count - 1)
        let slideAction = slides.isEmpty ? nil : slides[index].action
        let actionURL = slideAction.flatMap { resolveURL(for: $0) }
            ?? entry.configuration.items.first.flatMap { resolveItemURL($0) }
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
                if slide.isQRCode, let content = slide.qrCodeContent, !content.isEmpty,
                   let qr = UIImage.qrCode(from: content) {
                    GeometryReader { geo in
                        ZStack {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                            if let label = slide.qrCodeLabel, !label.isEmpty {
                                Text(label)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 3)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                    .padding(-10)
                } else {
                    let image = slide.imageData.flatMap { UIImage(data: $0) }
                        ?? SharedStorage.shared.loadWidgetImage(filename: slide.filename)
                    if let image {
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
                        .padding(-10)
                    } else {
                        Color.gray.opacity(0.3)
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
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
            } else if item.displayType == .qrCode, let content = item.qrCodeContent,
                      let qr = UIImage.qrCode(from: content, size: 60) {
                Image(uiImage: qr).resizable().scaledToFit()
            } else if item.displayType == .icon, let symbol = item.sfSymbolName {
                if symbol.hasPrefix("wi_") {
                    Image(symbol).resizable().renderingMode(.template).scaledToFit()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: symbol).font(.system(size: 30))
                }
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
                    if symbol.hasPrefix("wi_") {
                        Image(symbol).resizable().renderingMode(.template).scaledToFit()
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: symbol)
                    }
                    if let text = item.customText, !text.isEmpty { Text(text) }
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

    private var symbolSize: CGFloat { 14 }

    var body: some View {
        ZStack {
            item.backgroundColor.swiftUIColor
                .opacity(item.backgroundOpacity)

            if item.displayType == .qrCode, let content = item.qrCodeContent, !content.isEmpty,
               let qr = UIImage.qrCode(from: content) {
                ZStack {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                    if let label = item.qrCodeLabel, !label.isEmpty {
                        Text(label)
                            .font(.system(size: item.qrCodeLabelSize, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 2)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            } else if item.displayType == .image, let filename = item.customImageFilename,
               let image = (item.imageData.flatMap(UIImage.init)
                            ?? SharedStorage.shared.loadWidgetImage(filename: filename)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if item.displayType == .icon {
                VStack(spacing: 2) {
                    if let symbol = item.sfSymbolName {
                        if symbol.hasPrefix("wi_") {
                            Image(symbol)
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: symbolSize * 1.2, height: symbolSize * 1.2)
                                .foregroundStyle(item.foregroundColor.swiftUIColor)
                        } else {
                            Image(systemName: symbol)
                                .font(.system(size: symbolSize))
                                .foregroundStyle(item.foregroundColor.swiftUIColor)
                        }
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
                    .resizable().renderingMode(.original).scaledToFit()
                    .frame(width: 16, height: 16)
            } else if item.displayType == .qrCode, let content = item.qrCodeContent,
                      let qr = UIImage.qrCode(from: content, size: 32) {
                Image(uiImage: qr).resizable().scaledToFit().frame(width: 16, height: 16)
            } else if item.displayType == .icon, let symbol = item.sfSymbolName {
                if symbol.hasPrefix("wi_") {
                    Image(symbol).resizable().renderingMode(.template).scaledToFit()
                        .frame(width: 21, height: 21)
                } else {
                    Image(systemName: symbol).font(.system(size: 18))
                }
            } else {
                Text(item.customText?.prefix(1) ?? "").font(.system(size: 10))
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

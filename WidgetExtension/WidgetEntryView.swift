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
        itemGrid(items: Array(entry.configuration.items.prefix(9)),
                 cols: 3, rows: 3, size: .systemSmall)
    }

    private var mediumGrid: some View {
        itemGrid(items: Array(entry.configuration.items.prefix(18)),
                 cols: 6, rows: 3, size: .systemMedium)
    }

    private var largeGrid: some View {
        itemGrid(items: Array(entry.configuration.items.prefix(36)),
                 cols: 6, rows: 6, size: .systemLarge)
    }

    private var extraLargeGrid: some View { largeGrid }

    private func itemGrid(items: [WidgetItem], cols: Int, rows: Int, size: WidgetSize) -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = 1
            let cellW = (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols, id: \.self) { col in
                            let idx = row * cols + col
                            Group {
                                if idx < items.count {
                                    itemCell(items[idx], size: size)
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: cellW, height: cellH)
                        }
                    }
                }
            }
        }
        .padding(-10)
    }

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
        let hasNavigation = slides.count > 1

        ZStack {
            // Solid white base — visible in iOS 26 Clear/Liquid Glass mode where the
            // container background is replaced with a glass material. This ensures
            // the QR code always has a white surface to render on.
            Color.white

            if slides.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Add QR Code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                let slide = slides[index]
                if let content = slide.qrCodeContent, !content.isEmpty {
                    GeometryReader { geo in
                        ZStack {
                            QRCodeCanvasView(content: content)
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
                } else if let content = slide.barcodeContent, !content.isEmpty {
                    // Barcode: full-width, centred vertically with padding for readability
                    GeometryReader { geo in
                        ZStack {
                            BarcodeCanvasView(content: content)
                                .frame(width: geo.size.width, height: geo.size.height * 0.55)
                                .frame(width: geo.size.width, height: geo.size.height)
                            if let label = slide.qrCodeLabel, !label.isEmpty {
                                Text(label)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .padding(.top, geo.size.height * 0.62)
                            }
                        }
                    }
                    .padding(-10)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No content")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Corner navigation chevrons — bottom-left and bottom-right.
                // systemSmall only allows 1 interactive element; show forward-only there.
                if hasNavigation {
                    VStack {
                        Spacer()
                        HStack {
                            if widgetFamily != .systemSmall {
                                Button(intent: AdvanceImageIntent(
                                    widgetID: entry.configuration.id.uuidString, forward: false)) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.5))
                                        .padding(5)
                                        .background(Color(white: 0.5).opacity(0.15))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 3)
                                .padding(.bottom, 3)
                            }

                            Spacer()

                            Button(intent: AdvanceImageIntent(
                                widgetID: entry.configuration.id.uuidString, forward: true)) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.5))
                                    .padding(5)
                                    .background(Color(white: 0.5).opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 3)
                            .padding(.bottom, 3)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            if item.displayType == .qrCode, let content = item.qrCodeContent, !content.isEmpty {
                QRCodeCanvasView(content: content)
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

            if item.displayType == .qrCode, let content = item.qrCodeContent, !content.isEmpty {
                ZStack {
                    QRCodeCanvasView(content: content).padding(2)
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
            if item.displayType == .qrCode, let content = item.qrCodeContent, !content.isEmpty {
                QRCodeCanvasView(content: content).frame(width: 16, height: 16)
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

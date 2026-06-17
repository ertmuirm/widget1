import SwiftUI
import WidgetKit
import AppIntents

/// Main widget entry view that renders based on widget family
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    let entry: WidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            if entry.configuration.widgetKind == .imageSlideshow {
                imageSlideshowWidget
            } else if entry.configuration.widgetKind == .clock {
                clockWidget
            } else {
                homeScreenWidget
            }
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            lockScreenWidget
        default:
            homeScreenWidget
        }
    }

    // MARK: - Clock Widget

    @ViewBuilder
    private var clockWidget: some View {
        let position = entry.configuration.clockDigitPosition ?? .hour
        let fontSize = entry.configuration.clockFontSize ?? 80
        let calendar = Calendar.current
        let hour24 = calendar.component(.hour, from: entry.date)
        let minute = calendar.component(.minute, from: entry.date)
        let displayHour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        let actions = entry.configuration.clockActions ?? []

        if position == .time {
            let hourTens  = String((displayHour / 10) % 10)
            let hourUnits = String(displayHour % 10)
            let minTens   = String((minute / 10) % 10)
            let minUnits  = String(minute % 10)
            let a0 = actions.count > 0 ? resolveItemURL(actions[0]) : nil
            let a1 = actions.count > 1 ? resolveItemURL(actions[1]) : nil
            let a2 = actions.count > 2 ? resolveItemURL(actions[2]) : nil
            let a3 = actions.count > 3 ? resolveItemURL(actions[3]) : nil
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    clockDigitCell(digit: hourTens,  url: a0, fontSize: fontSize, side: .left)
                    clockDigitCell(digit: hourUnits, url: a1, fontSize: fontSize, side: .right)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 0) {
                    clockDigitCell(digit: minTens,  url: a2, fontSize: fontSize, side: .left)
                    clockDigitCell(digit: minUnits, url: a3, fontSize: fontSize, side: .right)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, -20)
            .padding(.vertical, -16)
        } else {
            let value = position == .hour ? displayHour : minute
            let tens = String((value / 10) % 10)
            let units = String(value % 10)
            let tensAction = actions.first.flatMap { resolveItemURL($0) }
            let unitsAction = actions.count > 1 ? resolveItemURL(actions[1]) : nil
            HStack(spacing: 0) {
                clockDigitCell(digit: tens,  url: tensAction,  fontSize: fontSize, side: .left)
                clockDigitCell(digit: units, url: unitsAction, fontSize: fontSize, side: .right)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, -20)
            .padding(.vertical, -16)
            .offset(x: -2)
        }
    }

    private enum ClockCellSide { case left, right }

    @ViewBuilder
    private func clockDigitCell(digit: String, url: URL?, fontSize: CGFloat,
                                side: ClockCellSide) -> some View {
        let foreground: Color = widgetRenderingMode == .vibrant ? .primary : .white
        // All digits are centered in their cells. The cells are then shifted inward
        // (left cell right, right cell left) by half the gap between cell width and a
        // typical digit width. This keeps wide digits (2-9, 0) in the same position as
        // the old trailing/leading layout while moving the narrow "1" toward the centre.
        GeometryReader { geo in
            let inset = max(0, (geo.size.width - fontSize * 0.575) / 2)
            let offsetX: CGFloat = side == .left ? inset : -inset
            ZStack {
                if let url = url {
                    Link(destination: url) {
                        Text(digit)
                            .font(clockFont(size: fontSize))
                            .minimumScaleFactor(0.3)
                            .foregroundStyle(foreground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                } else {
                    Text(digit)
                        .font(clockFont(size: fontSize))
                        .minimumScaleFactor(0.3)
                        .foregroundStyle(foreground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .offset(x: offsetX)
        }
    }

    private func clockFont(size: CGFloat) -> Font {
        if let name = entry.configuration.clockFontName {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .bold, design: .default)
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
            
            // DEBUG: Show refresh timestamp in top-left corner
            // This helps verify if getTimeline() is being called
            Text(entry.debugRefreshTime)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray)
                .padding(2)
                .background(Color.black.opacity(0.5))
                .cornerRadius(2)
                .offset(x: -20, y: -20)
        }
        // widgetURL fires for taps on areas not covered by a Link (gaps, empty cells).
        // The app's Page 0 is a black screen, so this tap silently opens and immediately
        // shows nothing — same UX as the old NoOpIntent approach, without consuming an
        // AppIntent interactive-element slot that would block Link rendering for grids
        // with many items.
        .widgetURL(URL(string: "widgetar://noop"))
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
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: cols),
            spacing: 1
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                itemCell(item, size: size)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

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
        let hasNavigation = slides.count > 1
        let actionURL: URL? = slides.isEmpty ? nil
            : (slides[index].action.flatMap { resolveURL(for: $0) }
               ?? entry.configuration.items.first.flatMap { resolveItemURL($0) })

        ZStack {
            // Solid white base — visible in iOS 26 Clear/Liquid Glass mode where the
            // container background is replaced with a glass material. This ensures
            // the QR code always has a white surface to render on.
            Color.white

            // NoOpIntent: only needed when there's no navigation (single/empty slide)
            // and no action configured — prevents the system from opening the app.
            if !hasNavigation && actionURL == nil {
                Button(intent: NoOpIntent()) { Color.clear }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .buttonStyle(.plain)
            }

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
                                    .font(.system(size: max(slide.qrCodeLabelSize, 7), weight: .bold))
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
                                VStack {
                                    Spacer()
                                    Text(label)
                                        .font(.system(size: max(slide.qrCodeLabelSize, 7), weight: .medium))
                                        .foregroundStyle(.black)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .padding(.bottom, 4)
                                }
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

                // Three invisible tap zones covering the full widget height:
                // left third = previous code, right third = next code,
                // center third = action item (falls through to widgetURL).
                if hasNavigation {
                    HStack(spacing: 0) {
                        Button(intent: AdvanceImageIntent(
                            widgetID: entry.entityUUID,
                            forward: false,
                            slideCount: slides.count)) {
                            Color.black.opacity(0.001)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if actionURL == nil {
                            Button(intent: NoOpIntent()) {
                                Color.black.opacity(0.001)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.black.opacity(0.001)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        Button(intent: AdvanceImageIntent(
                            widgetID: entry.entityUUID,
                            forward: true,
                            slideCount: slides.count)) {
                            Color.black.opacity(0.001)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

        }
        .widgetURL(actionURL)
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

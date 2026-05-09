import SwiftUI
import WidgetKit
import AppIntents

/// Clock widget entry view that renders digits in a 2x2 layout
struct ClockWidgetEntryView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            // Fully transparent background
            Color.clear
            
            // Render the digit at the appropriate position
            clockContent
        }
    }
    
    @ViewBuilder
    private var clockContent: some View {
        let items = entry.configuration.items
        
        HStack(spacing: 0) {
            // First digit
            if let item = items.first, let text = item.customText {
                digitView(text: text, fontSize: entry.configuration.clockFontSize ?? 48)
            }
            
            // Second digit
            if items.count > 1, let text = items[1].customText {
                digitView(text: text, fontSize: entry.configuration.clockFontSize ?? 48)
            }
        }
    }
    
    private func digitView(text: String, fontSize: CGFloat) -> some View {
        Text(text)
            .font(.custom(entry.configuration.clockFontName ?? "SF Pro", size: fontSize))
            .foregroundStyle(Color.white)
            .minimumScaleFactor(0.5)
    }
}

// MARK: - Preview

#Preview("Clock Hour", as: .systemMedium) {
    BroadcastClockWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfig(
        name: "Clock",
        size: .systemMedium,
        items: [
            WidgetItem(displayType: .text, customText: "1", fontSize: 48, foregroundColor: CodableColor.white, backgroundColor: CodableColor.clear, backgroundOpacity: 1.0, action: nil),
            WidgetItem(displayType: .text, customText: "2", fontSize: 48, foregroundColor: CodableColor.white, backgroundColor: CodableColor.clear, backgroundOpacity: 1.0, action: nil)
        ],
        backgroundColor: CodableColor.clear,
        backgroundOpacity: 0,
        widgetKind: .clock,
        clockDigitPosition: .hour,
        clockFontName: "SF Pro",
        clockFontSize: 48
    ))
}

#Preview("Clock Minute", as: .systemMedium) {
    BroadcastClockWidget()
} timeline: {
    WidgetEntry(date: .now, configuration: WidgetConfig(
        name: "Minute",
        size: .systemMedium,
        items: [
            WidgetItem(displayType: .text, customText: "0", fontSize: 48, foregroundColor: CodableColor.white, backgroundColor: CodableColor.clear, backgroundOpacity: 1.0, action: nil),
            WidgetItem(displayType: .text, customText: "5", fontSize: 48, foregroundColor: CodableColor.white, backgroundColor: CodableColor.clear, backgroundOpacity: 1.0, action: nil)
        ],
        backgroundColor: CodableColor.clear,
        backgroundOpacity: 0,
        widgetKind: .clock,
        clockDigitPosition: .minute,
        clockFontName: "Helvetica Neue",
        clockFontSize: 48
    ))
}
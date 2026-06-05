import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Widget Item Model

/// Represents a single item within a widget
struct WidgetItem: Codable, Identifiable, Equatable {
    let id: UUID
    var displayType: DisplayType
    var sfSymbolName: String?
    var customText: String?
    var fontSize: CGFloat
    var foregroundColor: CodableColor
    var backgroundColor: CodableColor
    var backgroundOpacity: Double
    var action: WidgetAction?
    
    init(
        id: UUID = UUID(),
        displayType: DisplayType = .icon,
        sfSymbolName: String? = "star.fill",
        customText: String? = nil,
        fontSize: CGFloat = 14,
        foregroundColor: CodableColor = CodableColor(.white),
        backgroundColor: CodableColor = CodableColor(.clear),
        backgroundOpacity: Double = 1.0,
        action: WidgetAction? = nil
    ) {
        self.id = id
        self.displayType = displayType
        self.sfSymbolName = sfSymbolName
        self.customText = customText
        self.fontSize = fontSize
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.action = action
    }
}

// MARK: - Display Type

enum DisplayType: String, Codable, CaseIterable {
    case icon
    case text
    
    var displayName: String {
        switch self {
        case .icon: return "Icon"
        case .text: return "Text"
        }
    }
}

// MARK: - Widget Configuration

/// Represents a complete widget configuration
struct WidgetConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var size: WidgetSize
    var items: [WidgetItem]
    var backgroundColor: CodableColor
    var backgroundOpacity: Double
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String = "New Widget",
        size: WidgetSize = .systemSmall,
        items: [WidgetItem] = [],
        backgroundColor: CodableColor = CodableColor(.black),
        backgroundOpacity: Double = 1.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.items = items
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Default configuration for placeholder
    static let defaultConfiguration = WidgetConfig(
        name: "My Widget",
        size: .systemSmall,
        items: [
            WidgetItem(
                id: UUID(),
                displayType: .icon,
                sfSymbolName: "star.fill",
                customText: nil,
                fontSize: 14,
                foregroundColor: CodableColor.white,
                backgroundColor: CodableColor.clear,
                backgroundOpacity: 1.0,
                action: nil
            )
        ],
        backgroundColor: CodableColor.black,
        backgroundOpacity: 1.0
    )
    
    /// Computed property for max items based on widget size
    var maxItems: Int {
        size.maxItems
    }
    
    /// Returns items truncated to maxItems
    var truncatedItems: [WidgetItem] {
        Array(items.prefix(maxItems))
    }
}

// MARK: - Widget Size

enum WidgetSize: String, Codable, CaseIterable {
    case systemSmall       // 1x1 (1 item)
    case systemMedium     // 3x3 (9 items)
    case systemLarge    // 6x3 (18 items)
    case systemExtraLarge // 6x6 (36 items)
    
    var displayName: String {
        switch self {
        case .systemSmall: return "Small (1×1)"
        case .systemMedium: return "Medium (3×3)"
        case .systemLarge: return "Large (6×3)"
        case .systemExtraLarge: return "Extra Large (6×6)"
        }
    }
    
    var maxItems: Int {
        switch self {
        case .systemSmall: return 1
        case .systemMedium: return 9
        case .systemLarge: return 18
        case .systemExtraLarge: return 36
        }
    }
    
    var columns: Int {
        switch self {
        case .systemSmall: return 1
        case .systemMedium: return 3
        case .systemLarge: return 6
        case .systemExtraLarge: return 6
        }
    }
    
    var rows: Int {
        switch self {
        case .systemSmall: return 1
        case .systemMedium: return 3
        case .systemLarge: return 3
        case .systemExtraLarge: return 6
        }
    }
}

// MARK: - Widget Action

/// Defines an action to be executed when a widget item is tapped
struct WidgetAction: Codable, Equatable {
    var type: ActionType
    var payload: String
    
    init(type: ActionType = .urlScheme, payload: String = "") {
        self.type = type
        self.payload = payload
    }
}

// MARK: - Action Type

enum ActionType: String, Codable, CaseIterable {
    case urlScheme
    case appIntent
    case shortcut
    
    var displayName: String {
        switch self {
        case .urlScheme: return "URL Scheme"
        case .appIntent: return "App Intent"
        case .shortcut: return "Shortcut"
        }
    }
    
    var description: String {
        switch self {
        case .urlScheme: return "Open a URL"
        case .appIntent: return "Run an App Intent"
        case .shortcut: return "Run a Shortcut"
        }
    }
}

// MARK: - Lock Screen Widget Families

/// Lock Screen widget family types
enum LockScreenWidgetFamily: String, Codable, CaseIterable {
    case accessoryInline
    case accessoryCircular
    case accessoryRectangular
    
    var displayName: String {
        switch self {
        case .accessoryInline: return "Inline"
        case .accessoryCircular: return "Circular"
        case .accessoryRectangular: return "Rectangular"
        }
    }
    
    var description: String {
        switch self {
        case .accessoryInline: return "Text and compact icons"
        case .accessoryCircular: return "Single icon or abbreviated text"
        case .accessoryRectangular: return "Up to 6 items"
        }
    }
    
    var maxItems: Int {
        switch self {
        case .accessoryInline: return 1
        case .accessoryCircular: return 1
        case .accessoryRectangular: return 6
        }
    }
}

// MARK: - Codable Color

/// A color that can be encoded/decoded
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(red: Double = 0, green: Double = 0, blue: Double = 0, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }
    
    #if canImport(UIKit)
    var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
    #endif
    
    #if canImport(SwiftUI)
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    #endif
    
    /// Standard colors
    static let clear = CodableColor(red: 0, green: 0, blue: 0, alpha: 0)
    static let black = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
}

// MARK: - App Group Storage Keys

enum StorageKeys {
    static let appGroupIdentifier = "group.com.iosmirror"
    static let widgetConfigurations = "widgetConfigurations"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let lastBackupDate = "lastBackupDate"
}

// MARK: - Export Format

struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let configurations: [WidgetConfig]

    init(configurations: [WidgetConfig]) {
        self.version = 1
        self.exportedAt = Date()
        self.configurations = configurations
    }
}

// MARK: - Push Command Entry

/// Maps a plain-text command received via ntfy.sh to a WidgetAction to execute
struct PushCommandEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var command: String       // raw text trigger, e.g. "kill-bluetooth"
    var label: String         // user-facing description
    var action: WidgetAction

    init(
        id: UUID = UUID(),
        command: String = "",
        label: String = "",
        action: WidgetAction = WidgetAction()
    ) {
        self.id = id
        self.command = command
        self.label = label
        self.action = action
    }
}

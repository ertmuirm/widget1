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
    var customImageFilename: String?  // used when displayType == .image
    var qrCodeContent: String?        // used when displayType == .qrCode
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
        customImageFilename: String? = nil,
        qrCodeContent: String? = nil,
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
        self.customImageFilename = customImageFilename
        self.qrCodeContent = qrCodeContent
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
    case image
    case qrCode

    var displayName: String {
        switch self {
        case .icon:   return "Icon"
        case .text:   return "Text"
        case .image:  return "Image"
        case .qrCode: return "QR Code"
        }
    }
}

// MARK: - Widget Kind

enum WidgetKind: String, Codable {
    case grid
    case imageSlideshow
    case lockScreen

    var displayName: String {
        switch self {
        case .grid:            return "Grid"
        case .imageSlideshow:  return "Image Slideshow"
        case .lockScreen:      return "Lock Screen"
        }
    }
}

// MARK: - Image Slide

/// One image in an Image Slideshow widget
struct ImageSlide: Codable, Identifiable, Equatable {
    let id: UUID
    var filename: String   // file stored in shared images directory
    var offsetX: Double    // -0.5 … 0.5 (fraction of widget width)
    var offsetY: Double    // -0.5 … 0.5 (fraction of widget height)
    var scale: Double      // 1.0 = fit, >1 = zoomed in
    var action: WidgetAction?
    /// In-memory JPEG data. Never serialized — populated at load time from SharedStorage.
    var imageData: Data?

    // imageData is intentionally excluded from JSON to keep config sizes small.
    enum CodingKeys: CodingKey { case id, filename, offsetX, offsetY, scale, action }

    init(id: UUID = UUID(), filename: String,
         offsetX: Double = 0, offsetY: Double = 0, scale: Double = 1.0,
         action: WidgetAction? = nil, imageData: Data? = nil) {
        self.id = id
        self.filename = filename
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.action = action
        self.imageData = imageData
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
    /// nil means "use system default (true)" — handled gracefully by older saved configs.
    var showItemLabels: Bool?
    /// nil means .grid (backwards compatible)
    var widgetKind: WidgetKind?
    /// Images for .imageSlideshow widgets
    var slides: [ImageSlide]?
    /// Currently displayed slide index for .imageSlideshow widgets
    var currentSlideIndex: Int?

    init(
        id: UUID = UUID(),
        name: String = "New Widget",
        size: WidgetSize = .systemSmall,
        items: [WidgetItem] = [],
        backgroundColor: CodableColor = CodableColor(.black),
        backgroundOpacity: Double = 1.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        showItemLabels: Bool? = nil,
        widgetKind: WidgetKind? = nil,
        slides: [ImageSlide]? = nil,
        currentSlideIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.items = items
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.showItemLabels = showItemLabels
        self.widgetKind = widgetKind
        self.slides = slides
        self.currentSlideIndex = currentSlideIndex
    }
    
    /// Default configuration for placeholder
    static let defaultConfiguration = WidgetConfig(
        name: "My Widget",
        size: .systemMedium,
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
    case systemSmall       // 3×3  (9 items)  — home screen Small
    case systemMedium      // 6×3  (18 items) — home screen Medium
    case systemLarge       // 6×6  (36 items) — home screen Large
    case systemExtraLarge  // kept for Codable backwards-compat; hidden from UI

    /// Sizes offered in the home-screen widget picker (excludes lock-screen-only / legacy sizes)
    static let homeScreenCases: [WidgetSize] = [.systemSmall, .systemMedium, .systemLarge]

    var displayName: String {
        switch self {
        case .systemSmall:      return "Small (3×3)"
        case .systemMedium:     return "Medium (6×3)"
        case .systemLarge:      return "Large (6×6)"
        case .systemExtraLarge: return "Extra Large (6×6)"
        }
    }

    var maxItems: Int {
        switch self {
        case .systemSmall:      return 9
        case .systemMedium:     return 18
        case .systemLarge:      return 36
        case .systemExtraLarge: return 36
        }
    }

    var columns: Int {
        switch self {
        case .systemSmall:      return 3
        case .systemMedium:     return 6
        case .systemLarge:      return 6
        case .systemExtraLarge: return 6
        }
    }

    var rows: Int {
        switch self {
        case .systemSmall:      return 3
        case .systemMedium:     return 3
        case .systemLarge:      return 6
        case .systemExtraLarge: return 6
        }
    }
}

// MARK: - Widget Action

/// Defines an action to be executed when a widget item is tapped
struct WidgetAction: Codable, Equatable {
    var type: ActionType
    var payload: String
    var displayName: String?

    init(type: ActionType = .urlScheme, payload: String = "", displayName: String? = nil) {
        self.type = type
        self.payload = payload
        self.displayName = displayName
    }
}

// MARK: - Action Type

enum ActionType: String, Codable, CaseIterable {
    case urlScheme
    case appIntent
    case shortcut
    case call

    var displayName: String {
        switch self {
        case .urlScheme:  return "URL Scheme"
        case .appIntent:  return "App Action"
        case .shortcut:   return "Shortcut"
        case .call:       return "Phone / WhatsApp Call"
        }
    }

    var description: String {
        switch self {
        case .urlScheme:  return "Enter a custom URL or deep link"
        case .appIntent:  return "Pick from a list of supported apps"
        case .shortcut:   return "Run a named Shortcut"
        case .call:       return "Call a phone number via Phone app or WhatsApp"
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
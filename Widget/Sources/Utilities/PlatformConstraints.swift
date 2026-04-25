import Foundation
import UIKit

/// Platform utilities for handling iOS version constraints
enum PlatformConstraints {
    
    // MARK: - Minimum Versions
    
    enum Minimum {
        static let homeScreenWidgets: Int = 14
        static let lockScreenWidgets: Int = 16
        static let interactiveWidgets: Int = 17
        static let liveActivities: Int = 16
    }
    
    // MARK: - Feature Availability
    
    /// Check if interactive widgets are available (iOS 17+)
    static var canShowInteractiveWidgets: Bool {
        #if canImport(WidgetKit)
        if #available(iOS 17.0, *) {
            return true
        }
        #endif
        return false
    }
    
    /// Check if Lock Screen widgets are available (iOS 16+)
    static var canShowLockScreenWidgets: Bool {
        #if canImport(WidgetKit)
        if #available(iOS 16.0, *) {
            return true
        }
        #endif
        return false
    }
    
    /// Check if Live Activities are available (iOS 16.1+)
    static var canShowLiveActivities: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return true
        }
        #endif
        return false
    }
}

// MARK: - iOS Limitations

/// Documented iOS limitations for the app
enum iOSLimitations {
    /// URL schemes may briefly flash the host app when opened from widgets
    static let urlSchemeFlashesApp = """
    Note: Opening URL schemes from widgets may briefly flash the host app.
    This is a system limitation that cannot be bypassed.
    """
    
    /// Control Center widgets are not supported via WidgetKit
    static let controlCenterNotSupported = """
    Note: Control Center widgets are not supported via WidgetKit.
    Use the Shortcuts app to create Control Center shortcuts.
    """
    
    /// Interactive widgets require iOS 17
    static let interactiveRequires17 = """
    Note: Interactive widgets require iOS 17 or later.
    On earlier versions, widgets will be non-interactive.
    """
    
    /// Shortcuts require user authorization
    static let shortcutsRequireAuth = """
    Note: Running shortcuts may require user authorization.
    The first run may show a system prompt.
    """
}

// MARK: - Widget Family Support

/// Utility for checking widget family support
struct WidgetFamilySupport {
    
    /// All supported Home Screen families
    static let homeScreenFamilies: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .systemExtraLarge
    ]
    
    /// All supported Lock Screen families (iOS 16+)
    static let lockScreenFamilies: [WidgetFamily] = [
        .accessoryCircular,
        .accessoryInline,
        .accessoryRectangular
    ]
    #if canImport(WidgetKit)
    @WidgetFamily(.systemSmall)
    #endif
    
    /// Check if a family is available on current iOS version
    static func isSupported(_ family: WidgetFamily) -> Bool {
        if #available(iOS 16.0, *) {
            switch family {
            case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
                return true
            case .accessoryCircular, .accessoryInline, .accessoryRectangular:
                return true
            default:
                return false
            }
        } else {
            switch family {
            case .systemSmall, .systemMedium, .systemLarge:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Error Handling

/// Errors that may occur due to iOS limitations
enum PlatformError: LocalizedError {
    case unsupportedIOSVersion(required: String)
    case featureNotAvailable(feature: String)
    case urlSchemeFailed(reason: String)
    case shortcutAuthorizationRequired
    
    var errorDescription: String? {
        switch self {
        case .unsupportedIOSVersion(let required):
            return "This feature requires iOS \(required) or later"
        case .featureNotAvailable(let feature):
            return "\(feature) is not available"
        case .urlSchemeFailed(let reason):
            return "Failed to open URL: \(reason)"
        case .shortcutAuthorizationRequired:
            return "Shortcut authorization required"
        }
    }
}

// MARK: - Safe Feature Wrappers

extension WidgetFamily {
    /// Safely get widget family display name
    var safeDisplayName: String {
        switch self {
        case .systemSmall: return "Small"
        case .systemMedium: return "Medium"
        case .systemLarge: return "Large"
        case .systemExtraLarge: return "Extra Large"
        case .accessoryCircular: return "Circular"
        case .accessoryInline: return "Inline"
        case .accessoryRectangular: return "Rectangular"
        default: return "Widget"
        }
    }
}
import Foundation

/// App-wide constants
enum Constants {
    // MARK: - App Group
    
    static let appGroupIdentifier = "group.com.iosmirror"
    
    // MARK: - Bundle IDs
    
    static let mainBundleID = "com.iosmirror"
    static let extensionBundleID = "com.iosmirror.broadcast"
    
    // MARK: - Storage Keys
    
    enum StorageKeys {
        // App Group ID - can be replaced by SideStore or injected at build time
        static let appGroupIdentifier = AppGroup.suiteName
        
        static let widgetConfigurations = "widgetConfigurations"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastBackupDate = "lastBackupDate"
        static let userPreferences = "userPreferences"
    }

    enum AppGroup {
        // 1. The original ID set in Xcode Signing & Capabilities
        static let rawId = "group.com.iosmirror"
        
        // 2. The User's Personal Team ID
        static let teamId = "J3D2F4SMVD"
        
        // 3. Robust Suite Name Getter using FileManager
        static var suiteName: String {
            // Try SideStore format: group.com.iosmirror.J3D2F4SMVD (team ID appended to suffix)
            let sideStoreId1 = "group.com.iosmirror.\(teamId)"
            // Alternative: group.J3D2F4SMVD.com.iosmirror
            let sideStoreId2 = "group.\(teamId).com.iosmirror"
            // Original
            let rawId = "group.com.iosmirror"
            
            // CHECK: Strict file system check using FileManager
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sideStoreId1) {
                print("✅ Active App Group (SideStore1): \(sideStoreId1)")
                print("📂 Container Path: \(container.path)")
                return sideStoreId1
            }
            else if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sideStoreId2) {
                print("✅ Active App Group (SideStore2): \(sideStoreId2)")
                print("📂 Container Path: \(container.path)")
                return sideStoreId2
            }
            else if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: rawId) {
                print("✅ Active App Group (Original): \(rawId)")
                return rawId
            }
            
            // Fallback for debugging
            print("❌ CRITICAL ERROR: No valid App Group container found for either ID.")
            return rawId
        }
        
        static var defaults: UserDefaults? {
            return UserDefaults(suiteName: suiteName)
        }
    }
    
    // MARK: - Widget Configuration
    
    enum Widget {
        static let refreshInterval: TimeInterval = 3600 // 1 hour
        static let maxConfigurations = 100
    }
    
    // MARK: - User Defaults Keys
    
    enum UserDefaultsKeys {
        static let showItemLabels = "showItemLabels"
        static let defaultWidgetSize = "defaultWidgetSize"
        static let hapticFeedback = "hapticFeedback"
        static let previewBackground = "previewBackground"
    }
}

// MARK: - iOS Version Check

import UIKit

enum iOSVersion {
    /// Check if running iOS 16.0+
    static var is16: Bool {
        #if swift(>=5.9)
        return UIDevice.current.systemVersion >= "16.0"
        #else
        return false
        #endif
    }
    
    /// Check if running iOS 17.0+
    static var is17: Bool {
        #if swift(>=5.9)
        return UIDevice.current.systemVersion >= "17.0"
        #else
        return false
        #endif
    }
    
    /// Current major version
    static var major: Int {
        let version = UIDevice.current.systemVersion
        return Int(version.split(separator: ".").first ?? "0") ?? 0
    }
}

// MARK: - SF Symbols Helpers

enum SFSymbols {
    // Common icons for widgets
    static let common = [
        "star.fill", "house.fill", "gear", "heart.fill", "bolt.fill", "flame.fill",
        "sun.max.fill", "moon.fill", "cloud.fill", "snow", "wind", "drop.fill",
        "leaf.fill", "camera.fill", "mic.fill", "music.note", "phone.fill", "envelope.fill",
        "message.fill", "bell.fill", "tag.fill", "cart.fill", "creditcard.fill", "gift.fill",
        "airplane", "car.fill", "bus.fill", "tram.fill", "bicycle", "figure.walk",
        "figure.run", "sportscourt.fill", "gamecontroller.fill", "paintbrush.fill", "pencil",
        "scissors", "doc.fill", "folder.fill", "trash.fill", "archivebox.fill",
        "clock.fill", "timer", "alarm.fill", "stopwatch.fill", "calendar",
        "map.fill", "location.fill", "compass.fill", "arrow.north.fill",
        "wifi", "antenna.radiowaves.left.and.right", "lock.fill", "unlock.fill",
        "eye.fill", "eye.slash.fill", "star.fill", "sparkle"
    ]
    
    /// Get a random symbol
    static func random() -> String {
        common.randomElement() ?? "star.fill"
    }
}

// MARK: - Userdefaults Helpers

extension UserDefaults {
    /// Convenience subscript for theme settings
    subscript<T>(key: String) -> T? {
        get { object(forKey: key) as? T }
        set { set(newValue, forKey: key) }
    }
}
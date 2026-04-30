import Foundation

/// App-wide constants
enum Constants {
    // MARK: - App Group
    
    static let appGroupIdentifier = "group.com.ioswidget"

    // MARK: - Bundle IDs

    static let mainBundleID = "com.ioswidget"
    static let extensionBundleID = "com.ioswidget.extension"
    
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
        static let rawId = "group.com.ioswidget"
        static let teamId = "J3D2F4SMVD"

        // Try all possible IDs
        static let allIDs = [
            "group.com.ioswidget.\(teamId)",
            "group.\(teamId).com.ioswidget",
            rawId
        ]
        
        static var suiteName: String {
            for id in allIDs {
                if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                    let testFile = container.appendingPathComponent(".test")
                    if FileManager.default.createFile(atPath: testFile.path, contents: nil) {
                        try? FileManager.default.removeItem(at: testFile)
                        print("✅ Active App Group: \(id)")
                        return id
                    }
                }
            }
            print("❌ CRITICAL ERROR: No valid App Group container found")
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

// MARK: - Custom Icons

enum CustomIcons {
    /// Icons with wi_ prefix — rendered from asset catalog, not SF Symbols
    static let all: [(name: String, label: String)] = [
        // Essentials
        ("wi_home",         "Home"),
        ("wi_person",       "Person"),
        ("wi_heart",        "Heart"),
        ("wi_star",         "Star"),
        ("wi_key",          "Key"),
        ("wi_lock",         "Lock"),
        ("wi_search",       "Search"),
        ("wi_settings",     "Settings"),
        ("wi_bell",         "Bell"),
        ("wi_bookmark",     "Bookmark"),
        // Communication
        ("wi_phone",        "Phone"),
        ("wi_mail",         "Mail"),
        ("wi_message",      "Message"),
        ("wi_mic",          "Microphone"),
        ("wi_share",        "Share"),
        // Media
        ("wi_camera",       "Camera"),
        ("wi_video",        "Video"),
        ("wi_photo",        "Photo"),
        ("wi_music",        "Music"),
        ("wi_headphones",   "Headphones"),
        ("wi_tv",           "TV"),
        ("wi_remote",       "Remote"),
        // Productivity
        ("wi_calendar",     "Calendar"),
        ("wi_clock",        "Clock"),
        ("wi_alarm",        "Alarm"),
        ("wi_edit",         "Edit"),
        ("wi_file",         "File"),
        ("wi_folder",       "Folder"),
        ("wi_trash",        "Trash"),
        ("wi_download",     "Download"),
        ("wi_upload",       "Upload"),
        // Intelligence & Language
        ("wi_ai",           "AI"),
        ("wi_translate",    "Translate"),
        ("wi_globe",        "Globe"),
        ("wi_questionmark", "Question"),
        ("wi_lightbulb",    "Lightbulb"),
        // Transport
        ("wi_car",          "Car"),
        ("wi_airplane",     "Airplane"),
        ("wi_train",        "Train"),
        ("wi_transit",      "Transit"),
        ("wi_bicycle",      "Bicycle"),
        ("wi_navigation",   "Navigation"),
        ("wi_map",          "Map"),
        // Nature & Weather
        ("wi_sun",          "Sun"),
        ("wi_moon",         "Moon"),
        ("wi_cloud",        "Cloud"),
        // Tech & Connectivity
        ("wi_wifi",         "Wi-Fi"),
        ("wi_bluetooth",    "Bluetooth"),
        ("wi_battery",      "Battery"),
        ("wi_qrcode",       "QR Code"),
        ("wi_barcode",      "Barcode"),
        // Commerce
        ("wi_shopping",     "Shopping"),
        ("wi_wallet",       "Wallet"),
    ]

    static func isCustom(_ name: String) -> Bool { name.hasPrefix("wi_") }
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

// MARK: - Widget icon rendering helper

import SwiftUI

/// Renders either a custom wi_ asset-catalog icon or an SF Symbol.
struct WidgetIconImage: View {
    let name: String
    var fontSize: CGFloat = 20

    var body: some View {
        if CustomIcons.isCustom(name) {
            Image(name)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: fontSize * 1.2, height: fontSize * 1.2)
        } else {
            Image(systemName: name)
                .font(.system(size: fontSize))
        }
    }
}

// MARK: - UIImage downscaling for widget storage

extension UIImage {
    /// Returns a copy scaled so the longest edge is at most 1024 px.
    /// This keeps keychain items well under the ~4 MB limit while
    /// preserving more than enough resolution for any widget display size.
    func downsizedForWidget(maxDimension: CGFloat = 1024) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
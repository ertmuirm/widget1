import AppIntents
import UIKit

// MARK: - Widget Action Intent

/// App Intent for handling widget tap actions
struct WidgetActionIntent: AppIntent {
    static var title: LocalizedStringResource = "Widget Action"
    static var description = IntentDescription("Executes a widget action from the home screen")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Action Type")
    var actionType: String
    
    @Parameter(title: "Payload")
    var payload: String
    
    init() {
        self.actionType = "urlScheme"
        self.payload = ""
    }
    
    init(actionType: String, payload: String) {
        self.actionType = actionType
        self.payload = payload
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch actionType {
        case "urlScheme":
            return await performURLScheme()
        case "appIntent":
            return await performAppIntent()
        case "shortcut":
            return await performShortcut()
        default:
            return .result(dialog: "Unknown action type")
        }
    }
    
    @MainActor
    private func performURLScheme() async -> some IntentResult & ProvidesDialog {
        guard let url = URL(string: payload) else {
            return .result(dialog: "Invalid URL")
        }
        
        let success = await UIApplication.shared.open(url)
        
        if success {
            return .result(dialog: "Opened URL")
        } else {
            return .result(dialog: "Could not open URL")
        }
    }
    
    @MainActor
    private func performAppIntent() async -> some IntentResult & ProvidesDialog {
        // Note: Actual app intent execution requires the intent to be defined
        // This is a placeholder for system intents
        return .result(dialog: "Ran app intent: \(payload)")
    }
    
    @MainActor
    private func performShortcut() async -> some IntentResult & ProvidesDialog {
        let encodedName = payload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? payload
        let urlString = "shortcuts://run shortcut?name=\(encodedName)"
        
        guard let url = URL(string: urlString) else {
            return .result(dialog: "Invalid shortcut name")
        }
        
        let success = await UIApplication.shared.open(url)
        
        if success {
            return .result(dialog: "Ran shortcut: \(payload)")
        } else {
            return .result(dialog: "Could not run shortcut")
        }
    }
}

// MARK: - Widget Intents Provider

struct WidgetIntentsProvider {
    static func getIntent(for item: WidgetItem) -> WidgetActionIntent? {
        guard let action = item.action else { return nil }
        return WidgetActionIntent(actionType: action.type.rawValue, payload: action.payload)
    }
}

// MARK: - App Shortcuts Provider

/// Provides app shortcuts for widget interactions
struct WidgetAppShortcuts: AppShortcutsProvider {
    static var shortcuts: [WidgetActionIntent] {
        // Example shortcut intents that can be triggered from widgets
        [
            WidgetActionIntent(actionType: "urlScheme", payload: "https://example.com"),
            WidgetActionIntent(actionType: "appIntent", payload: "openURL")
        ]
    }
}
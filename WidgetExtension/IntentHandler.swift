import AppIntents
import UIKit

/// App Intent for handling widget tap actions
struct WidgetActionIntent: AppIntent {
    static var title: LocalizedStringResource = "Widget Action"
    static var description = IntentDescription("Executes a widget action")
    
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
    
    func perform() async throws -> some IntentResult {
        switch actionType {
        case "urlScheme":
            if let url = URL(string: payload) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        case "appIntent":
            // Execute app intent
            break
        case "shortcut":
            // Execute shortcut via Intents framework
            break
        default:
            break
        }
        return .result()
    }
}

/// Provider for widget intents
struct WidgetIntentsProvider {
    static func getIntent(for item: WidgetItem) -> WidgetActionIntent? {
        guard let action = item.action else { return nil }
        return WidgetActionIntent(actionType: action.type.rawValue, payload: action.payload)
    }
}
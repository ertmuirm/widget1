import AppIntents

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
            return .result(dialog: "Opening: \(payload)")
        case "appIntent":
            return .result(dialog: "Running: \(payload)")
        case "shortcut":
            return .result(dialog: "Shortcut: \(payload)")
        default:
            return .result(dialog: "Unknown action")
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

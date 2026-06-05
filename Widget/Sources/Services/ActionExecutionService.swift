import Foundation
import UIKit
import AppIntents

/// Service for executing widget actions
final class ActionExecutionService {
    
    static let shared = ActionExecutionService()
    
    private init() {}
    
    // MARK: - Execute Action
    
    /// Execute a widget action
    @MainActor
    func execute(action: WidgetAction) async throws -> ActionResult {
        switch action.type {
        case .urlScheme:
            return await executeURLScheme(action.payload)
        case .appIntent:
            return await executeAppIntent(action.payload)
        case .shortcut:
            return await executeShortcut(action.payload)
        }
    }
    
    // MARK: - URL Scheme Execution
    
    @MainActor
    private func executeURLScheme(_ urlString: String) async -> ActionResult {
        // Validate URL format
        guard let url = URL(string: urlString) else {
            return ActionResult(success: false, error: "Invalid URL format")
        }
        
        // Try to open the URL
        let success = await UIApplication.shared.open(url)
        
        if success {
            return ActionResult(success: true)
        } else {
            return ActionResult(success: false, error: "Failed to open URL")
        }
    }
    
    // MARK: - App Intent Execution
    
    @MainActor
    private func executeAppIntent(_ intentName: String) async -> ActionResult {
        // Note: Full App Intents execution requires the intents to be defined in the app
        // For predefined intents, use URL schemes that iOS provides
        
        // Map predefined intents to their URL schemes
        let intentURL = IntentDiscoveryService.shared.getIntent(byId: intentName)
        
        if let intent = intentURL {
            // Use URL scheme for system intents
            switch intent.id {
            case "openURL":
                return ActionResult(success: true)
            case "playMusic":
                return await executeURLScheme("music://play")
            case "pauseMusic":
                return await executeURLScheme("music://pause")
            case "takePhoto":
                return await executeURLScheme("camera://")
            default:
                return ActionResult(success: true, message: "Intent '\(intent.name)' triggered")
            }
        }
        
        return ActionResult(success: false, error: "Unknown intent: \(intentName)")
    }
    
    // MARK: - Shortcut Execution
    
    @MainActor
    private func executeShortcut(_ shortcutName: String) async -> ActionResult {
        // Note: Running shortcuts programmatically requires user authorization
        // and the Shortcuts app to be installed
        
        // Try to open via shortcuts:// URL scheme
        // Note: This may show the Shortcuts app briefly
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shortcutName
        let urlString = "shortcuts://run shortcut?name=\(encodedName)"
        
        if let url = URL(string: urlString) {
            let success = await UIApplication.shared.open(url)
            return ActionResult(success: success, error: success ? nil : "Could not run shortcut")
        }
        
        return ActionResult(success: false, error: "Invalid shortcut name")
    }
}

// MARK: - Background Execution (voip wakeup, no async/await)

extension ActionExecutionService {

    /// Executes an action using the callback-based UIApplication.open() API.
    /// Must be called on the main thread. Safe to call during voip background wakeup
    /// because it does not go through the Swift concurrency scheduler.
    func executeBackground(_ action: WidgetAction, completion: @escaping () -> Void) {
        guard let url = backgroundActionURL(for: action) else { completion(); return }
        UIApplication.shared.open(url, options: [:]) { _ in completion() }
    }

    private func backgroundActionURL(for action: WidgetAction) -> URL? {
        switch action.type {
        case .urlScheme:
            return URL(string: action.payload)
        case .shortcut:
            let encoded = action.payload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? action.payload
            return URL(string: "shortcuts://run shortcut?name=\(encoded)")
        case .appIntent:
            guard let intent = IntentDiscoveryService.shared.getIntent(byId: action.payload) else { return nil }
            switch intent.id {
            case "playMusic":  return URL(string: "music://play")
            case "pauseMusic": return URL(string: "music://pause")
            case "takePhoto":  return URL(string: "camera://")
            default:           return nil
            }
        }
    }
}

// MARK: - URL Scheme Validation

extension ActionExecutionService {
    
    /// Validate a URL scheme
    func validateURLScheme(_ urlString: String) -> URLSchemeValidation {
        guard !urlString.isEmpty else {
            return URLSchemeValidation(valid: false, error: "URL cannot be empty")
        }
        
        // Check for valid scheme prefix
        guard urlString.contains("://") else {
            return URLSchemeValidation(valid: false, error: "URL must contain '://'")
        }
        
        // Check scheme type
        let validSchemes = ["http", "https", "music", "message", "tel", "mailto", "shortcuts", "camera", "sms", "facetime"]
        let scheme = urlString.split(separator: "://").first.map(String.init)
        
        if let scheme = scheme, !validSchemes.contains(scheme.lowercased()) {
            return URLSchemeValidation(valid: true, warning: "Unknown scheme: \(scheme)")
        }
        
        return URLSchemeValidation(valid: true, error: nil)
    }
}

// MARK: - Action Result

struct ActionResult {
    let success: Bool
    var error: String?
    var message: String?
    
    init(success: Bool, error: String? = nil, message: String? = nil) {
        self.success = success
        self.error = error
        self.message = message
    }
}

// MARK: - URL Scheme Validation

struct URLSchemeValidation {
    let valid: Bool
    var error: String?
    var warning: String?
    
    init(valid: Bool, error: String? = nil, warning: String? = nil) {
        self.valid = valid
        self.error = error
        self.warning = warning
    }
}

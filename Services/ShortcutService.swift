import Foundation
import Intents

/// Service for discovering and executing Shortcuts
final class ShortcutService {
    
    static let shared = ShortcutService()
    
    private init() {}
    
    // MARK: - Shortcut Discovery
    
    /// Get available shortcuts from the user's Shortcuts library
    /// Note: Full access is required to read all shortcuts
    func getAvailableShortcuts() async throws -> [ShortcutInfo] {
        // In a real implementation, this would use INShortcutsLibrary
        // For now, return sample shortcuts
        return [
            ShortcutInfo(id: "sample1", name: "Morning Routine", subtitle: "Good morning shortcut"),
            ShortcutInfo(id: "sample2", name: "Quick Note", subtitle: "Create a note"),
            ShortcutInfo(id: "sample3", name: "Directions Home", subtitle: "Get directions to home")
        ]
    }
    
    /// Get shortcut by name
    func getShortcut(byName name: String) async throws -> ShortcutInfo? {
        let shortcuts = try await getAvailableShortcuts()
        return shortcuts.first { $0.name == name }
    }
    
    // MARK: - Shortcut Execution
    
    /// Execute a shortcut by name
    /// Note: This requires user authorization and interaction
    @discardableResult
    func executeShortcut(named name: String) async throws -> Bool {
        // In a real implementation, use INVocabulary shortcut with shared
        // For now, just simulate execution
        let intent = IntentDiscoveryService.shared.getIntent(byId: name)
        if intent != nil {
            return true
        }
        throw ShortcutError.notFound
    }
}

// MARK: - Shortcut Info

struct ShortcutInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String?
}

// MARK: - Shortcut Errors

enum ShortcutError: LocalizedError {
    case notFound
    case authorizationDenied
    case executionFailed
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Shortcut not found"
        case .authorizationDenied:
            return "Authorization to run shortcuts was denied"
        case .executionFailed:
            return "Failed to execute shortcut"
        }
    }
}
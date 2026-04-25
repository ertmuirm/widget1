import Foundation

/// Service for discovering and managing App Intents
final class IntentDiscoveryService {
    
    static let shared = IntentDiscoveryService()
    
    private init() {}
    
    // MARK: - Predefined Common Intents
    
    /// Common intents available on iOS
    static let commonIntents: [PredefinedIntent] = [
        PredefinedIntent(id: "openURL", name: "Open URL", description: "Opens a URL in Safari"),
        PredefinedIntent(id: "playMusic", name: "Play Music", description: "Plays music in the Music app"),
        PredefinedIntent(id: "pauseMusic", name: "Pause Music", description: "Pauses music playback"),
        PredefinedIntent(id: "nextTrack", name: "Next Track", description: "Skips to the next track"),
        PredefinedIntent(id: "previousTrack", name: "Previous Track", description: "Skips to the previous track"),
        PredefinedIntent(id: "sendMessage", name: "Send Message", description: "Sends a message via Messages app"),
        PredefinedIntent(id: "makeCall", name: "Make Call", description: "Initiates a phone call"),
        PredefinedIntent(id: "setAlarm", name: "Set Alarm", description: "Sets an alarm"),
        PredefinedIntent(id: "startTimer", name: "Start Timer", description: "Starts a timer"),
        PredefinedIntent(id: "addReminder", name: "Add Reminder", description: "Adds a reminder")
    ]
    
    // MARK: - Intent Discovery
    
    /// Get available intents (could be extended to detect installed apps)
    func getAvailableIntents() -> [PredefinedIntent] {
        // In a real implementation, this would scan for installed apps that expose App Intents
        // For now, return predefined intents with installed app filtering
        return Self.commonIntents
    }
    
    /// Get intent by ID
    func getIntent(byId id: String) -> PredefinedIntent? {
        Self.commonIntents.first { $0.id == id }
    }
}

// MARK: - Predefined Intent

struct PredefinedIntent: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
}
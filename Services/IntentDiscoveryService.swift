import Foundation

/// Service for discovering and managing App Intents
final class IntentDiscoveryService {
    
    static let shared = IntentDiscoveryService()
    
    private init() {}
    
    // MARK: - Predefined Common Intents
    
    /// Common intents available on iOS
    static let commonIntents: [PredefinedIntent] = [
        // System intents
        PredefinedIntent(id: "openURL", name: "Open URL", description: "Opens a URL in Safari", category: .system),
        PredefinedIntent(id: "playMusic", name: "Play Music", description: "Plays music in the Music app", category: .media),
        PredefinedIntent(id: "pauseMusic", name: "Pause Music", description: "Pauses music playback", category: .media),
        PredefinedIntent(id: "nextTrack", name: "Next Track", description: "Skips to the next track", category: .media),
        PredefinedIntent(id: "previousTrack", name: "Previous Track", description: "Skips to the previous track", category: .media),
        PredefinedIntent(id: "sendMessage", name: "Send Message", description: "Sends a message via Messages app", category: .communication),
        PredefinedIntent(id: "makeCall", name: "Make Call", description: "Initiates a phone call", category: .communication),
        PredefinedIntent(id: "setAlarm", name: "Set Alarm", description: "Sets an alarm", category: .productivity),
        PredefinedIntent(id: "startTimer", name: "Start Timer", description: "Starts a timer", category: .productivity),
        PredefinedIntent(id: "addReminder", name: "Add Reminder", description: "Adds a reminder", category: .productivity),
        // Quick actions
        PredefinedIntent(id: "takePhoto", name: "Take Photo", description: "Opens camera", category: .camera),
        PredefinedIntent(id: "scanDocument", name: "Scan Document", description: "Scans a document", category: .productivity),
        PredefinedIntent(id: "toggleFlashlight", name: "Toggle Flashlight", description: "Turns flashlight on/off", category: .system),
        PredefinedIntent(id: "openWallet", name: "Open Wallet", description: "Opens Apple Wallet", category: .shopping),
        PredefinedIntent(id: "airplaneMode", name: "Airplane Mode", description: "Toggle Airplane Mode", category: .system)
    ]
    
    // MARK: - Intent Discovery
    
    /// Get available intents
    func getAvailableIntents() -> [PredefinedIntent] {
        Self.commonIntents
    }
    
    /// Get intents by category
    func getIntents(byCategory category: IntentCategory) -> [PredefinedIntent] {
        Self.commonIntents.filter { $0.category == category }
    }
    
    /// Get intent by ID
    func getIntent(byId id: String) -> PredefinedIntent? {
        Self.commonIntents.first { $0.id == id }
    }
    
    /// Search intents
    func searchIntents(query: String) -> [PredefinedIntent] {
        guard !query.isEmpty else { return Self.commonIntents }
        return Self.commonIntents.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Intent Category

enum IntentCategory: String, CaseIterable {
    case system
    case media
    case communication
    case productivity
    case camera
    case shopping
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var iconName: String {
        switch self {
        case .system: return "gear"
        case .media: return "music.note"
        case .communication: return "message"
        case .productivity: return "checklist"
        case .camera: return "camera"
        case .shopping: return "cart"
        }
    }
}

// MARK: - Predefined Intent

struct PredefinedIntent: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let category: IntentCategory
    
    init(id: String, name: String, description: String, category: IntentCategory = .system) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
    }
}
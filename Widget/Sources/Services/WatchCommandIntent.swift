import AppIntents

// MARK: - Device entity

struct SavedWatchEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Watch Device")
    }
    static var defaultQuery = SavedWatchQuery()

    var id: String   // device UUID string
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) { self.id = id; self.name = name }
}

struct SavedWatchQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SavedWatchEntity] {
        BLEDeviceStore.shared.devices
            .filter { identifiers.contains($0.id.uuidString) }
            .map { SavedWatchEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func suggestedEntities() async throws -> [SavedWatchEntity] {
        let devs = BLEDeviceStore.shared.devices
        guard !devs.isEmpty else { return [SavedWatchEntity(id: "none", name: "No saved devices")] }
        return devs.map { SavedWatchEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func defaultResult() async -> SavedWatchEntity? {
        BLEDeviceStore.shared.devices.first.map { SavedWatchEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

// MARK: - Command entity

struct WatchCommandEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Watch Command")
    }
    static var defaultQuery = WatchCommandQuery()

    var id: String        // preset UUID string
    var label: String
    var deviceID: String  // owning device UUID string (for display disambiguation)

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(label)")
    }

    init(id: String, label: String, deviceID: String) {
        self.id = id; self.label = label; self.deviceID = deviceID
    }
}

struct WatchCommandQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WatchCommandEntity] {
        BLEDeviceStore.shared.devices.flatMap { dev in
            (dev.vibrationPresets + dev.notificationPresets)
                .filter { identifiers.contains($0.id.uuidString) }
                .map { WatchCommandEntity(id: $0.id.uuidString, label: $0.label, deviceID: dev.id.uuidString) }
        }
    }

    func suggestedEntities() async throws -> [WatchCommandEntity] {
        BLEDeviceStore.shared.devices.flatMap { dev in
            (dev.vibrationPresets + dev.notificationPresets)
                .map { WatchCommandEntity(id: $0.id.uuidString, label: $0.label, deviceID: dev.id.uuidString) }
        }
    }

    func defaultResult() async -> WatchCommandEntity? {
        guard let dev = BLEDeviceStore.shared.devices.first,
              let preset = (dev.vibrationPresets + dev.notificationPresets).first
        else { return nil }
        return WatchCommandEntity(id: preset.id.uuidString, label: preset.label, deviceID: dev.id.uuidString)
    }
}

// MARK: - Intent

struct SendWatchCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Watch Command"
    static var description = IntentDescription("Send a Vibration or Notification command to a paired smartwatch over Bluetooth. The watch must be nearby. Save devices in the app's Bluetooth menu first.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Device", description: "The saved watch to send the command to")
    var device: SavedWatchEntity

    @Parameter(title: "Command", description: "The preset command to send")
    var command: WatchCommandEntity

    init() {}
    init(device: SavedWatchEntity, command: WatchCommandEntity) {
        self.device = device; self.command = command
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let savedDevice = BLEDeviceStore.shared.device(withIDString: device.id) else {
            return .result(dialog: IntentDialog(stringLiteral: "Device \(device.name) not found. Open the app and save the device first."))
        }
        let allPresets = savedDevice.vibrationPresets + savedDevice.notificationPresets
        guard let preset = allPresets.first(where: { $0.id.uuidString == command.id }),
              !preset.hexSequence.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral: "Command not found. Open the app and re-save the device."))
        }
        do {
            let executor = BLECommandExecutor()
            let timeout = TimeInterval(BLEDeviceStore.shared.commandTimeoutSeconds)
            try await executor.execute(
                peripheralID: savedDevice.id,
                writeCharUUID: savedDevice.writeTargetUUID,
                hexSequence: preset.hexSequence,
                timeout: timeout
            )
            return .result(dialog: IntentDialog(stringLiteral: "\(preset.label) sent to \(savedDevice.name)."))
        } catch let err as BLECommandError {
            return .result(dialog: IntentDialog(stringLiteral: err.errorDescription ?? "Command failed."))
        } catch {
            return .result(dialog: IntentDialog(stringLiteral: "Bluetooth error: \(error.localizedDescription)"))
        }
    }
}

import AppIntents

// MARK: - Device entity

struct SavedBLEEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "BLE Device")
    }
    static var defaultQuery = SavedBLEQuery()

    var id: String   // device UUID string
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) { self.id = id; self.name = name }
}

struct SavedBLEQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SavedBLEEntity] {
        BLEDeviceStore.shared.devices
            .filter { identifiers.contains($0.id.uuidString) }
            .map { SavedBLEEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func suggestedEntities() async throws -> [SavedBLEEntity] {
        let devs = BLEDeviceStore.shared.devices
        guard !devs.isEmpty else { return [SavedBLEEntity(id: "none", name: "No saved devices")] }
        return devs.map { SavedBLEEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func defaultResult() async -> SavedBLEEntity? {
        BLEDeviceStore.shared.devices.first.map { SavedBLEEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

// MARK: - Write Command entity

struct WriteCommandEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Write Command")
    }
    static var defaultQuery = WriteCommandQuery()

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

struct WriteCommandQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WriteCommandEntity] {
        BLEDeviceStore.shared.devices.flatMap { dev in
            (dev.vibrationPresets + dev.notificationPresets)
                .filter { identifiers.contains($0.id.uuidString) }
                .map { WriteCommandEntity(id: $0.id.uuidString, label: $0.label, deviceID: dev.id.uuidString) }
        }
    }

    func suggestedEntities() async throws -> [WriteCommandEntity] {
        BLEDeviceStore.shared.devices.flatMap { dev in
            (dev.vibrationPresets + dev.notificationPresets)
                .map { WriteCommandEntity(id: $0.id.uuidString, label: $0.label, deviceID: dev.id.uuidString) }
        }
    }

    func defaultResult() async -> WriteCommandEntity? {
        guard let dev = BLEDeviceStore.shared.devices.first,
              let preset = (dev.vibrationPresets + dev.notificationPresets).first
        else { return nil }
        return WriteCommandEntity(id: preset.id.uuidString, label: preset.label, deviceID: dev.id.uuidString)
    }
}

// MARK: - Read Preset entity

struct ReadPresetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Read Preset")
    }
    static var defaultQuery = ReadPresetQuery()

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

struct ReadPresetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ReadPresetEntity] {
        BLEDeviceStore.shared.devices.flatMap { dev in
            dev.readPresets
                .filter { identifiers.contains($0.id.uuidString) }
                .map { ReadPresetEntity(id: $0.id.uuidString, label: $0.label, deviceID: dev.id.uuidString) }
        }
    }

    func suggestedEntities() async throws -> [ReadPresetEntity] {
        BLEDeviceStore.shared.devices.flatMap { dev in
            dev.readPresets
                .map { ReadPresetEntity(id: $0.id.uuidString, label: $0.label, deviceID: dev.id.uuidString) }
        }
    }

    func defaultResult() async -> ReadPresetEntity? {
        guard let dev = BLEDeviceStore.shared.devices.first,
              let preset = dev.readPresets.first
        else { return nil }
        return ReadPresetEntity(id: preset.id.uuidString, label: preset.label, deviceID: dev.id.uuidString)
    }
}

// MARK: - Send BLE Command Intent

struct SendBLECommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Send BLE Command"
    static var description = IntentDescription("Send a Vibration or Notification command to a paired BLE device over Bluetooth. The device must be nearby. Save devices in the app's Bluetooth menu first.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Device", description: "The saved BLE device to send the command to")
    var device: SavedBLEEntity

    @Parameter(title: "Command", description: "The preset command to send")
    var command: WriteCommandEntity

    init() {}
    init(device: SavedBLEEntity, command: WriteCommandEntity) {
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

// MARK: - Read BLE Data Intent

struct ReadBLEDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Read BLE Data"
    static var description = IntentDescription("Read a value from a BLE device characteristic. The device must be nearby. Save devices and read presets in the app's Bluetooth menu first.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Device", description: "The saved BLE device to read from")
    var device: SavedBLEEntity

    @Parameter(title: "Read Preset", description: "The preset defining which service/characteristic to read")
    var preset: ReadPresetEntity

    @Parameter(title: "Output Format", description: "How to format the output value")
    var format: BLEDataFormat

    init() {}
    init(device: SavedBLEEntity, preset: ReadPresetEntity, format: BLEDataFormat) {
        self.device = device; self.preset = preset; self.format = format
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let savedDevice = BLEDeviceStore.shared.device(withIDString: device.id) else {
            return .result(value: "", dialog: IntentDialog(stringLiteral: "Device \(device.name) not found. Open the app and save the device first."))
        }

        guard let readPreset = savedDevice.readPresets.first(where: { $0.id.uuidString == preset.id }) else {
            return .result(value: "", dialog: IntentDialog(stringLiteral: "Read preset not found. Open the app and re-save the device."))
        }

        do {
            let executor = BLEReadExecutor()
            let timeout = TimeInterval(BLEDeviceStore.shared.commandTimeoutSeconds)
            let data = try await executor.execute(
                peripheralID: savedDevice.id,
                serviceUUID: readPreset.serviceUUID,
                characteristicUUID: readPreset.characteristicUUID,
                timeout: timeout
            )

            let formattedValue = formatData(data, format: format)
            return .result(
                value: formattedValue,
                dialog: IntentDialog(stringLiteral: "\(readPreset.label): \(formattedValue)")
            )
        } catch let err as BLEReadError {
            return .result(value: "", dialog: IntentDialog(stringLiteral: err.errorDescription ?? "Read failed."))
        } catch {
            return .result(value: "", dialog: IntentDialog(stringLiteral: "Bluetooth error: \(error.localizedDescription)"))
        }
    }

    private func formatData(_ data: Data, format: BLEDataFormat) -> String {
        switch format {
        case .decimal:
            if data.count == 1 {
                return String(data[0])
            } else if data.count <= 8 {
                var value: UInt64 = 0
                for byte in data {
                    value = (value << 8) | UInt64(byte)
                }
                return String(value)
            } else {
                // For longer data, return space-separated decimal bytes
                return data.map { String($0) }.joined(separator: " ")
            }
        case .ascii:
            return data.printableASCII.isEmpty ? data.hexString : data.printableASCII
        case .hex:
            return data.hexString
        }
    }
}

enum BLEDataFormat: String, AppEnum {
    case decimal = "Decimal"
    case ascii = "ASCII"
    case hex = "Hex"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Output Format"

    static var caseDisplayRepresentations: [BLEDataFormat: DisplayRepresentation] = [
        .decimal: "Decimal (e.g., 85 for battery level)",
        .ascii: "ASCII (e.g., ABC123 for text data)",
        .hex: "Hex (e.g., 55 for battery level)"
    ]
}

// MARK: - Read BLE Battery Intent

/// Reads the battery level from a paired BLE device using the Battery Service (180F/2A19).
/// This uses the Cloud Battery approach to bypass iOS GATT service hiding for system accessories.
/// Also supports HeyCyan smart glasses via their vendor SDK.
struct ReadBLEBatteryIntent: AppIntent {
    static var title: LocalizedStringResource = "Read BLE Battery"
    static var description = IntentDescription("Reads the battery level from a paired BLE device. Works with system accessories that iOS normally hides from third-party apps. Supports HeyCyan smart glasses via SDK.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Device", description: "The saved BLE device to read battery from")
    var device: SavedBLEEntity

    init() {}
    init(device: SavedBLEEntity) {
        self.device = device
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let savedDevice = BLEDeviceStore.shared.device(withIDString: device.id) else {
            return .result(value: 0, dialog: IntentDialog(stringLiteral: "Device \(device.name) not found. Open the app and save the device first."))
        }

        // Try HeyCyan SDK first (for smart glasses)
        if device.name.lowercased().contains("heycyan") || 
           device.name.lowercased().contains("glasses") ||
           device.name.lowercased().contains("eyewear") {
            if let level = try? await HeyCyanService.shared.readBatteryLevel() {
                return .result(
                    value: level,
                    dialog: IntentDialog(stringLiteral: "\(device.name) battery: \(level)% (HeyCyan SDK)")
                )
            }
        }

        // Try standard BLE battery read
        do {
            let batteryLevel = try await BLEManager.shared.readBatteryLevel(for: savedDevice.id)
            return .result(
                value: batteryLevel,
                dialog: IntentDialog(stringLiteral: "\(device.name) battery: \(batteryLevel)%")
            )
        } catch let err as BLEReadError {
            return .result(value: 0, dialog: IntentDialog(stringLiteral: err.errorDescription ?? "Battery read failed."))
        } catch {
            return .result(value: 0, dialog: IntentDialog(stringLiteral: "Bluetooth error: \(error.localizedDescription)"))
        }
    }
}

// MARK: - App Shortcuts Provider

/// Only expose the BLE-related intents in Shortcuts.
/// Other AppIntents (NoOpIntent, AdvanceImageIntent) are for widget button use only.
struct WidgetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendBLECommandIntent(),
            phrases: [
                "Send BLE Command to \(.applicationName)",
                "Control BLE device with \(.applicationName)"
            ],
            shortTitle: "Send BLE Command",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
        AppShortcut(
            intent: ReadBLEDataIntent(),
            phrases: [
                "Read BLE Data with \(.applicationName)",
                "Get BLE sensor value from \(.applicationName)"
            ],
            shortTitle: "Read BLE Data",
            systemImageName: "sensor.tag.radiowaves.forward"
        )
        AppShortcut(
            intent: ReadBLEBatteryIntent(),
            phrases: [
                "Read BLE Battery with \(.applicationName)",
                "Check \(.applicationName) device battery"
            ],
            shortTitle: "Read BLE Battery",
            systemImageName: "battery.100"
        )
    }
}

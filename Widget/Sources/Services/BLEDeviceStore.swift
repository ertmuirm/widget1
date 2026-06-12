import Foundation

struct BLEPreset: Codable, Identifiable {
    var id: UUID
    var label: String
    var hexSequence: [String]

    init(id: UUID = UUID(), label: String, hexSequence: [String]) {
        self.id = id
        self.label = label
        self.hexSequence = hexSequence
    }
}

struct SavedBLEDevice: Codable, Identifiable {
    var id: UUID               // CBPeripheral.identifier
    var name: String
    var writeTargetUUID: String
    var vibrationPresets: [BLEPreset]
    var notificationPresets: [BLEPreset]
}

final class BLEDeviceStore: ObservableObject {
    static let shared = BLEDeviceStore()

    @Published private(set) var devices: [SavedBLEDevice] = []
    @Published var commandTimeoutSeconds: Int = 10 {
        didSet { UserDefaults.standard.set(commandTimeoutSeconds, forKey: Self.timeoutKey) }
    }

    private static let storageKey = "ble_saved_devices_v2"
    private static let timeoutKey = "ble_command_timeout_v1"

    static let defaultVibrationPresets: [BLEPreset] = [
        BLEPreset(label: "Vibration OFF", hexSequence: ["df0006f1020108000100"]),
        BLEPreset(label: "Vibration ON",  hexSequence: ["df0006f2020108000101"]),
    ]

    static let defaultNotificationPresets: [BLEPreset] = [
        BLEPreset(label: "Notif ALL ON",  hexSequence: [
            "df00199502012200143333333333333333333333",
            "330000000000000000",
        ]),
        BLEPreset(label: "Notif ALL OFF", hexSequence: [
            "df0019fd02012200141111111111111111111111",
            "110000000000000000",
        ]),
    ]

    private init() {
        let stored = UserDefaults.standard.integer(forKey: Self.timeoutKey)
        commandTimeoutSeconds = stored > 0 ? stored : 10
        load()
    }

    func upsert(_ device: SavedBLEDevice) {
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        } else {
            devices.append(device)
        }
        save()
    }

    func delete(id: UUID) {
        devices.removeAll { $0.id == id }
        save()
    }

    func device(withID id: UUID) -> SavedBLEDevice? {
        devices.first { $0.id == id }
    }

    func device(withIDString id: String) -> SavedBLEDevice? {
        UUID(uuidString: id).flatMap { device(withID: $0) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let loaded = try? JSONDecoder().decode([SavedBLEDevice].self, from: data)
        else { return }
        devices = loaded
    }
}

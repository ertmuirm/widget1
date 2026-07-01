import AppIntents
import CoreBluetooth

// MARK: - Read BLE Data Intent

/// Self-contained BLE reader for use from App Intents.
final class BLEReadExecutor: NSObject, NSObject {
    private let queue = DispatchQueue(label: "com.ioswidget.ble-read-executor", qos: .userInitiated)
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var readCharUUID: CBUUID?
    
    private var continuation: CheckedContinuation<Data, Error>?
    private var overallTimeoutWork: DispatchWorkItem?
    private var commandTimeout: TimeInterval = 10
    private var pendingServiceCount = 0
    private var discoveredServiceCount = 0
    private var readData: Data?
    
    private let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FFF0"),
        CBUUID(string: "FFE0"),
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"),
    ]
    
    func execute(peripheralID: UUID, readCharUUID: String, timeout: TimeInterval = 10) async throws -> Data {
        self.readCharUUID = CBUUID(string: readCharUUID)
        self.commandTimeout = max(0, timeout)
        pendingServiceCount = 0
        discoveredServiceCount = 0
        readData = nil
        
        return try await withCheckedThrowingContinuation { [self] (cont: CheckedContinuation<Data, Error>) in
            continuation = cont
            if commandTimeout > 0 {
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.central?.stopScan()
                    if let p = self.peripheral { self.central?.cancelPeripheralConnection(p) }
                    self.resume(.failure(BLECommandError.timeout))
                }
                overallTimeoutWork = work
                queue.asyncAfter(deadline: .now() + commandTimeout, execute: work)
            }
            central = CBCentralManager(delegate: self, queue: queue,
                                       options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }
    
    private func resume(_ result: Result<Data, Error>) {
        overallTimeoutWork?.cancel()
        overallTimeoutWork = nil
        let cont = continuation
        continuation = nil
        cont?.resume(with: result)
    }
}

extension BLEReadExecutor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            resume(.failure(BLECommandError.bluetoothUnavailable)); return
        }
        guard let targetID = peripheral?.identifier ?? nil else {
            resume(.failure(BLECommandError.deviceNotFound)); return
        }
        
        // Try already-connected peripherals first
        let connected = central.retrieveConnectedPeripherals(withServices: knownServiceUUIDs)
        if let found = connected.first(where: { $0.identifier == targetID }) {
            found.delegate = self
            peripheral = found
            central.connect(found, options: nil)
            return
        }
        
        // Try retrieve by identifier
        let retrieved = central.retrievePeripherals(withIdentifiers: [targetID])
        if let found = retrieved.first {
            found.delegate = self
            peripheral = found
            central.connect(found, options: nil)
            return
        }
        
        // Fall back to scan
        guard commandTimeout > 0 else {
            resume(.failure(BLECommandError.deviceNotFound)); return
        }
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard peripheral.identifier == self.peripheral?.identifier else { return }
        central.stopScan()
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        resume(.failure(BLECommandError.connectionFailed(error?.localizedDescription ?? "unknown")))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if let data = readData {
            resume(.success(data))
        } else if let error {
            resume(.failure(BLECommandError.connectionFailed(error.localizedDescription)))
        } else {
            resume(.failure(BLECommandError.timeout))
        }
    }
}

extension BLEReadExecutor: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { resume(.failure(error)); return }
        guard let services = peripheral.services, !services.isEmpty else {
            resume(.failure(BLECommandError.characteristicNotFound)); return
        }
        pendingServiceCount = services.count
        discoveredServiceCount = 0
        for svc in services { peripheral.discoverCharacteristics(nil, for: svc) }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { resume(.failure(error)); return }
        discoveredServiceCount += 1
        
        if let charUUID = readCharUUID,
           let characteristic = service.characteristics?.first(where: { $0.uuid == charUUID }) {
            // Subscribe to notifications if available, otherwise read once
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
        
        if discoveredServiceCount == pendingServiceCount && readData == nil {
            // If we didn't find and read the characteristic, try reading from the first available
            if let firstChar = service.characteristics?.first(where: { $0.properties.contains(.read) }) {
                peripheral.readValue(for: firstChar)
            } else {
                resume(.failure(BLECommandError.characteristicNotFound))
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { return } // Ignore errors on update, we might get more data later
        if let value = characteristic.value, !value.isEmpty {
            readData = value
            // Disconnect after receiving data
            central?.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - BLE Read Entity

struct BLEDeviceReadEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "BLE Device")
    }
    static var defaultQuery = BLEDeviceReadQuery()
    
    var id: String   // device UUID string
    var name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    init(id: String, name: String) { self.id = id; self.name = name }
}

struct BLEDeviceReadQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BLEDeviceReadEntity] {
        BLEDeviceStore.shared.devices
            .filter { identifiers.contains($0.id.uuidString) }
            .map { BLEDeviceReadEntity(id: $0.id.uuidString, name: $0.name) }
    }
    
    func suggestedEntities() async throws -> [BLEDeviceReadEntity] {
        let devs = BLEDeviceStore.shared.devices
        guard !devs.isEmpty else { return [BLEDeviceReadEntity(id: "none", name: "No saved devices")] }
        return devs.map { BLEDeviceReadEntity(id: $0.id.uuidString, name: $0.name) }
    }
    
    func defaultResult() async -> BLEDeviceReadEntity? {
        BLEDeviceStore.shared.devices.first.map { BLEDeviceReadEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

// MARK: - Read BLE Data Intent

struct ReadBLEDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Read BLE Data"
    static var description = IntentDescription("Reads data from a saved BLE device. Returns raw hex data from the device's read characteristic.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Device", description: "The saved BLE device to read from")
    var device: BLEDeviceReadEntity
    
    init() {}
    init(device: BLEDeviceReadEntity) { self.device = device }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let savedDevice = BLEDeviceStore.shared.device(withIDString: device.id) else {
            return .result(value: "", dialog: IntentDialog(stringLiteral: "Device \(device.name) not found. Open the app and save the device first."))
        }
        
        // Use the read characteristic UUID from the saved device
        let readCharUUID = savedDevice.readTargetUUID
        guard !readCharUUID.isEmpty else {
            return .result(value: "", dialog: IntentDialog(stringLiteral: "No read characteristic configured for \(savedDevice.name). Configure one in the app first."))
        }
        
        let executor = BLEReadExecutor()
        let timeout = TimeInterval(BLEDeviceStore.shared.commandTimeoutSeconds)
        
        do {
            let data = try await executor.execute(
                peripheralID: savedDevice.id,
                readCharUUID: readCharUUID,
                timeout: timeout
            )
            
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            return .result(value: hexString, dialog: IntentDialog(stringLiteral: "Read \(data.count) bytes from \(savedDevice.name): \(hexString)"))
        } catch let err as BLECommandError {
            return .result(value: "", dialog: IntentDialog(stringLiteral: err.errorDescription ?? "Read failed."))
        } catch {
            return .result(value: "", dialog: IntentDialog(stringLiteral: "Bluetooth error: \(error.localizedDescription)"))
        }
    }
}

// MARK: - App Shortcuts Provider

struct ReadBLEDataShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadBLEDataIntent(),
            phrases: [
                "Read BLE data in \(.applicationName)",
                "Read Bluetooth data",
            ],
            shortTitle: "Read BLE Data",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
    }
}

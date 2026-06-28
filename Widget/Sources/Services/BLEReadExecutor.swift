import Foundation
import CoreBluetooth

enum BLEReadError: LocalizedError {
    case bluetoothUnavailable
    case deviceNotFound
    case connectionFailed(String)
    case characteristicNotFound
    case readFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:    return "Bluetooth is unavailable"
        case .deviceNotFound:        return "Device not found — make sure the device is nearby"
        case .connectionFailed(let m): return "Connection failed: \(m)"
        case .characteristicNotFound: return "Read characteristic not found on device"
        case .readFailed(let m):      return "Read failed: \(m)"
        case .timeout:               return "Operation timed out"
        }
    }
}

/// Self-contained BLE executor for reading characteristics.
/// Creates its own CBCentralManager, connects to a specific peripheral by UUID,
/// reads a characteristic value, then disconnects.
final class BLEReadExecutor: NSObject {

    enum OutputFormat: String, CaseIterable {
        case decimal = "Decimal"
        case ascii = "ASCII"
        case hex = "Hex"
    }

    private let queue = DispatchQueue(label: "com.ioswidget.ble-read-executor", qos: .userInitiated)
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?

    private var targetPeripheralID: UUID?
    private var targetServiceUUID: CBUUID?
    private var targetCharUUID: CBUUID?

    private var continuation: CheckedContinuation<Data, Error>?
    private var overallTimeoutWork: DispatchWorkItem?
    private var commandTimeout: TimeInterval = 10
    private var didRead = false
    private var pendingServiceCount = 0
    private var discoveredServiceCount = 0

    // Battery read mode - scans all characteristics to find battery indicator
    private var isBatteryReadMode = false
    private var discoveredCharacteristics: [(service: CBService, characteristic: CBCharacteristic)] = []
    private var characteristicsToRead: [(service: CBService, characteristic: CBCharacteristic)] = []

    /// Common battery characteristic UUIDs (standard BLE)
    private let batteryCharacteristicUUIDs: [CBUUID] = [
        CBUUID(string: "2A19"),  // Battery Level (standard)
        CBUUID(string: "2A25"),  // Battery Level (alternate)
        CBUUID(string: "2A26"),  // Battery Level State
        CBUUID(string: "2A27"),  // Battery Level Power State
    ]

    /// Extended service UUIDs for Cloud Battery approach
    private let extendedServiceUUIDs: [CBUUID] = [
        // Standard BLE services
        CBUUID(string: "180F"),  // Battery Service
        CBUUID(string: "180A"),  // Device Information
        CBUUID(string: "1800"),  // Generic Access
        CBUUID(string: "1801"),  // Generic Attribute
        CBUUID(string: "180D"),  // Heart Rate
        // Common BLE device services
        CBUUID(string: "FFF0"),
        CBUUID(string: "FFE0"),
        CBUUID(string: "FFE1"),
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9F"),  // Nordic UART
        // Apple-specific services (for AirPods, etc.)
        CBUUID(string: "D0611E78-BBB4-4591-A5F8-487910AE4366"),  // Apple Continuity
        CBUUID(string: "8667556C-9A37-4C91-84ED-54EE27D90049"),  // Apple Audio
    ]

    /// Known service UUIDs for general device discovery
    private let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FFF0"),
        CBUUID(string: "FFE0"),
        CBUUID(string: "180D"),  // Heart Rate
        CBUUID(string: "180A"),  // Device Information
        CBUUID(string: "1800"),  // Generic Access
        CBUUID(string: "1801"),  // Generic Attribute
        CBUUID(string: "180F"),  // Battery Service
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9F"),  // Nordic UART
    ]

    func execute(peripheralID: UUID, serviceUUID: String, characteristicUUID: String,
                 timeout: TimeInterval = 10) async throws -> Data {
        targetPeripheralID = peripheralID
        targetServiceUUID = CBUUID(string: serviceUUID)
        targetCharUUID = CBUUID(string: characteristicUUID)
        self.commandTimeout = max(0, timeout)
        didRead = false
        pendingServiceCount = 0
        discoveredServiceCount = 0
        isBatteryReadMode = serviceUUID.isEmpty || characteristicUUID.isEmpty
        discoveredCharacteristics = []
        characteristicsToRead = []

        return try await withCheckedThrowingContinuation { [self] (cont: CheckedContinuation<Data, Error>) in
            continuation = cont
            if commandTimeout > 0 {
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.central?.stopScan()
                    if let p = self.peripheral { self.central?.cancelPeripheralConnection(p) }
                    if !self.didRead {
                        self.resume(.failure(BLEReadError.timeout))
                    }
                }
                overallTimeoutWork = work
                queue.asyncAfter(deadline: .now() + commandTimeout, execute: work)
            }
            // Use restore identifier for background state persistence (Cloud Battery approach)
            let options: [String: Any] = [
                CBCentralManagerOptionShowPowerAlertKey: false,
                CBCentralManagerOptionRestoreIdentifierKey: "com.ioswidget.bleread.restoration"
            ]
            central = CBCentralManager(delegate: self, queue: queue, options: options)
        }
    }

    // Must be called on self.queue.
    private func resume(_ result: Result<Data, Error>) {
        overallTimeoutWork?.cancel()
        overallTimeoutWork = nil
        let cont = continuation
        continuation = nil
        cont?.resume(with: result)
    }

    private func disconnect() {
        guard let p = peripheral else { return }
        central?.cancelPeripheralConnection(p)
    }

    // MARK: - Cloud Battery: Try to find peripheral from system-connected devices
    private func findSystemConnectedPeripheral(_ central: CBCentralManager) -> CBPeripheral? {
        // Step 1: Try retrievePeripherals first - this works for ANY device we've seen before,
        // including cached devices that iOS has stored from previous connections.
        // This is the KEY fix for headphones that Apple Cloud Battery can see!
        let retrieved = central.retrievePeripherals(withIdentifiers: [targetPeripheralID!])
        if let found = retrieved.first {
            return found
        }

        // Step 2: Try with Battery Service specifically
        let batteryConnected = central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "180F")])
        if let found = batteryConnected.first(where: { $0.identifier == targetPeripheralID }) {
            return found
        }

        // Step 3: Try extended service UUIDs
        let extendedConnected = central.retrieveConnectedPeripherals(withServices: extendedServiceUUIDs)
        if let found = extendedConnected.first(where: { $0.identifier == targetPeripheralID }) {
            return found
        }

        // Step 4: Finally, try known service UUIDs
        let knownConnected = central.retrieveConnectedPeripherals(withServices: knownServiceUUIDs)
        if let found = knownConnected.first(where: { $0.identifier == targetPeripheralID }) {
            return found
        }

        return nil
    }

    // MARK: - Battery Detection Helper
    private func isLikelyBatteryValue(_ data: Data) -> Bool {
        // Battery level is typically a single byte with value 0-100
        guard data.count >= 1, data.count <= 4 else { return false }
        
        // Check if all bytes could represent a battery percentage (0-100)
        if data.count == 1 {
            let value = data[0]
            return value <= 100
        }
        
        // For multi-byte values, check if reading as little-endian gives 0-100
        if data.count == 2 {
            let value = UInt16(data[0]) | (UInt16(data[1]) << 8)
            return value <= 100
        }
        
        return false
    }

    private func readNextBatteryCharacteristic() {
        guard !characteristicsToRead.isEmpty else {
            // No more characteristics to try
            resume(.failure(BLEReadError.characteristicNotFound))
            return
        }

        let next = characteristicsToRead.removeFirst()
        peripheral?.readValue(for: next.characteristic)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEReadExecutor: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            resume(.failure(BLEReadError.bluetoothUnavailable)); return
        }
        guard let targetID = targetPeripheralID else {
            resume(.failure(BLEReadError.deviceNotFound)); return
        }

        // Step 1: Try to find from system-connected devices (Cloud Battery approach)
        // This works for AirPods, Apple Watch, and other iOS-managed devices
        if let found = findSystemConnectedPeripheral(central) {
            found.delegate = self
            peripheral = found
            // If already connected by system, discover services directly
            if found.state == .connected {
                found.discoverServices(nil)
            } else {
                central.connect(found, options: nil)
            }
            return
        }

        // Step 2: Try retrieve by identifier (cached from prior sessions or previously seen devices)
        // This is crucial - even if not "connected" via retrieveConnectedPeripherals,
        // we may have seen this device before and can reconnect
        let retrieved = central.retrievePeripherals(withIdentifiers: [targetID])
        if let found = retrieved.first {
            found.delegate = self
            peripheral = found
            central.connect(found, options: nil)
            return
        }

        // Step 3: Fall back to scan. If timeout is 0, skip scan.
        guard commandTimeout > 0 else {
            resume(.failure(BLEReadError.deviceNotFound)); return
        }
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        // Restore state from background - handle reconnected peripherals
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let targetID = targetPeripheralID,
           let found = peripherals.first(where: { $0.identifier == targetID }) {
            peripheral = found
            found.delegate = self
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard peripheral.identifier == targetPeripheralID else { return }
        central.stopScan()
        peripheral.delegate = self
        self.peripheral = peripheral
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Discover all services - for Cloud Battery devices, Battery Service will be available
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        resume(.failure(BLEReadError.connectionFailed(error?.localizedDescription ?? "unknown")))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if !didRead {
            resume(.failure(BLEReadError.timeout))
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEReadExecutor: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { resume(.failure(error)); return }
        guard let services = peripheral.services, !services.isEmpty else {
            resume(.failure(BLEReadError.characteristicNotFound)); return
        }
        pendingServiceCount = services.count
        discoveredServiceCount = 0
        
        // Discover characteristics for all services
        for svc in services { 
            peripheral.discoverCharacteristics(nil, for: svc)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { resume(.failure(error)); return }
        discoveredServiceCount += 1

        guard let chars = service.characteristics, !chars.isEmpty else {
            if discoveredServiceCount == pendingServiceCount {
                // All services discovered, handle based on mode
                if isBatteryReadMode {
                    handleBatteryModeServiceDiscoveryComplete()
                } else if !didRead {
                    resume(.failure(BLEReadError.characteristicNotFound))
                }
            }
            return
        }

        // Collect all readable characteristics
        for char in chars {
            let hasReadProperty = char.properties.contains(.read)
            let isBatteryUUID = batteryCharacteristicUUIDs.contains(char.uuid)

            if isBatteryReadMode {
                // In battery mode, collect all readable characteristics
                if hasReadProperty {
                    discoveredCharacteristics.append((service: service, characteristic: char))
                    characteristicsToRead.append((service: service, characteristic: char))
                }
            } else {
                // Specific target mode - look for exact match
                guard let targetChar = targetCharUUID,
                      let targetSvc = targetServiceUUID
                else {
                    if discoveredServiceCount == pendingServiceCount && !didRead {
                        resume(.failure(BLEReadError.characteristicNotFound))
                    }
                    return
                }

                if char.uuid == targetChar && service.uuid == targetSvc {
                    // Found the exact characteristic - read it
                    peripheral.readValue(for: char)
                    return
                }
            }
        }

        // Check if we've discovered all services
        if discoveredServiceCount == pendingServiceCount && !didRead {
            if isBatteryReadMode {
                handleBatteryModeServiceDiscoveryComplete()
            } else {
                resume(.failure(BLEReadError.characteristicNotFound))
            }
        }
    }

    private func handleBatteryModeServiceDiscoveryComplete() {
        // Sort characteristics to try standard battery UUIDs first
        characteristicsToRead.sort { a, b in
            let aIsBattery = batteryCharacteristicUUIDs.contains(a.characteristic.uuid)
            let bIsBattery = batteryCharacteristicUUIDs.contains(b.characteristic.uuid)
            if aIsBattery && !bIsBattery { return true }
            if !aIsBattery && bIsBattery { return false }
            return a.characteristic.uuid.uuidString < b.characteristic.uuid.uuidString
        }

        // Start reading characteristics
        readNextBatteryCharacteristic()
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            // On read error, try next characteristic
            if isBatteryReadMode && !characteristicsToRead.isEmpty {
                readNextBatteryCharacteristic()
            } else if !didRead {
                resume(.failure(BLEReadError.readFailed(error.localizedDescription)))
            }
            return
        }

        guard let data = characteristic.value else {
            // No data, try next characteristic
            if isBatteryReadMode && !characteristicsToRead.isEmpty {
                readNextBatteryCharacteristic()
            } else if !didRead {
                resume(.failure(BLEReadError.readFailed("No data received")))
            }
            return
        }

        if isBatteryReadMode {
            // Check if this looks like a battery value
            if isLikelyBatteryValue(data) {
                // Success! Found a battery-like value
                didRead = true
                disconnect()
                resume(.success(data))
            } else if !characteristicsToRead.isEmpty {
                // Not a battery value, try next
                readNextBatteryCharacteristic()
            } else {
                // No more to try
                resume(.failure(BLEReadError.characteristicNotFound))
            }
        } else {
            // Specific target mode
            guard characteristic.uuid == targetCharUUID else { return }
            didRead = true
            disconnect()
            resume(.success(data))
        }
    }
}

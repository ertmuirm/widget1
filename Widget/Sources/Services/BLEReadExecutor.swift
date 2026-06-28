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

    /// Extended service UUIDs for Cloud Battery approach - includes many services
    /// that might contain battery or other readable characteristics
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

    func execute(peripheralID: UUID, serviceUUID: String, characteristicUUID: String,
                 timeout: TimeInterval = 10) async throws -> Data {
        targetPeripheralID = peripheralID
        targetServiceUUID = CBUUID(string: serviceUUID)
        targetCharUUID = CBUUID(string: characteristicUUID)
        self.commandTimeout = max(0, timeout)
        didRead = false
        pendingServiceCount = 0
        discoveredServiceCount = 0

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
        // Try Battery Service first (most common for Cloud Battery)
        let batteryConnected = central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "180F")])
        if let found = batteryConnected.first(where: { $0.identifier == targetPeripheralID }) {
            return found
        }

        // Try extended service UUIDs
        let extendedConnected = central.retrieveConnectedPeripherals(withServices: extendedServiceUUIDs)
        if let found = extendedConnected.first(where: { $0.identifier == targetPeripheralID }) {
            return found
        }

        return nil
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

        // Step 2: Try retrieve by identifier (cached from prior sessions)
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
        
        // If we have a specific service UUID, only discover characteristics for that service
        if let targetSvc = targetServiceUUID,
           let service = services.first(where: { $0.uuid == targetSvc }) {
            peripheral.discoverCharacteristics([targetCharUUID!], for: service)
        } else {
            // Discover all characteristics to find the target
            for svc in services { peripheral.discoverCharacteristics(nil, for: svc) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { resume(.failure(error)); return }
        discoveredServiceCount += 1

        guard let targetChar = targetCharUUID,
              let char = service.characteristics?.first(where: { $0.uuid == targetChar })
        else {
            // Check if we've discovered all services and still haven't found the characteristic
            if discoveredServiceCount == pendingServiceCount && !didRead {
                resume(.failure(BLEReadError.characteristicNotFound))
            }
            return
        }

        // Read the characteristic value
        peripheral.readValue(for: char)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            if !didRead { resume(.failure(BLEReadError.readFailed(error.localizedDescription))) }
            return
        }

        guard characteristic.uuid == targetCharUUID,
              let data = characteristic.value
        else {
            if !didRead { resume(.failure(BLEReadError.readFailed("No data received"))) }
            return
        }

        didRead = true
        disconnect()
        resume(.success(data))
    }
}

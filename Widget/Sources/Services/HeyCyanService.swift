import Foundation
import CoreBluetooth

/// HeyCyan Smart Glasses BLE Service
/// 
/// This service handles battery reading from HeyCyan smart glasses via their
/// vendor-specific BLE profile. Based on the ebowwa/HeyCyanSmartGlassesSDK:
/// 
/// Service UUID: 7905FFF0-B5CE-4E99-A40F-4B1E122D00D0
/// Characteristic UUID: 6e40fff0-b5a3-f393-e0a9-e50e24dcca9e
/// 
/// The SDK documentation shows these are the primary BLE identifiers.
/// Battery level can be read using the QCSDKCmdCreator.getDeviceBattery() command.
final class HeyCyanService: NSObject, ObservableObject {

    static let shared = HeyCyanService()

    // MARK: - HeyCyan BLE UUIDs
    static let heyCyanServiceUUID = CBUUID(string: "7905FFF0-B5CE-4E99-A40F-4B1E122D00D0")
    static let heyCyanCharacteristicUUID = CBUUID(string: "6e40fff0-b5a3-f393-e0a9-e50e24dcca9e")
    
    // Alternative UUIDs from SDK documentation
    static let heyCyanAltServiceUUID = CBUUID(string: "FFF0")
    static let heyCyanAltCharacteristicUUID = CBUUID(string: "FFF1")

    // MARK: - Published State
    @Published private(set) var isConnected = false
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var isCharging = false
    @Published private(set) var deviceName: String?
    @Published private(set) var deviceIdentifier: UUID?

    // MARK: - Private State
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var batteryCharacteristic: CBCharacteristic?
    private var pendingReadContinuations: [CheckedContinuation<Int, Error>] = []
    private let queue = DispatchQueue(label: "com.ioswidget.heycyan.service", qos: .userInitiated)

    // MARK: - Initialization

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }

    // MARK: - Public API

    /// Check if a device identifier matches a HeyCyan device by scanning for it
    func isHeyCyanDevice(identifier: UUID) async -> Bool {
        guard centralManager?.state == .poweredOn else { return false }
        
        return await withCheckedContinuation { continuation in
            // Try to retrieve the peripheral
            let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [identifier]) ?? []
            if let peripheral = peripherals.first {
                // Check if it matches HeyCyan service UUIDs
                let name = peripheral.name?.lowercased() ?? ""
                if name.contains("heycyan") || name.contains("glasses") || name.contains("js-01") {
                    continuation.resume(returning: true)
                    return
                }
            }
            continuation.resume(returning: false)
        }
    }

    /// Connect to HeyCyan device and read battery level
    func readBatteryLevel(for peripheralID: UUID) async throws -> Int {
        guard centralManager?.state == .poweredOn else {
            throw HeyCyanError.bluetoothUnavailable
        }

        // First try to find in cache
        let cachedPeripherals = centralManager?.retrievePeripherals(withIdentifiers: [peripheralID]) ?? []
        if let peripheral = cachedPeripherals.first {
            return try await connectAndReadBattery(peripheral)
        }

        // Try system-connected
        let systemConnected = centralManager?.retrieveConnectedPeripherals(withServices: [
            Self.heyCyanServiceUUID,
            Self.heyCyanAltServiceUUID
        ]) ?? []
        
        if let peripheral = systemConnected.first(where: { $0.identifier == peripheralID }) {
            return try await connectAndReadBattery(peripheral)
        }

        // Not found
        throw HeyCyanError.deviceNotFound
    }

    /// Read battery from cached HeyCyan device
    func readBatteryLevel() async throws -> Int {
        guard let peripheralID = deviceIdentifier else {
            throw HeyCyanError.deviceNotConnected
        }
        return try await readBatteryLevel(for: peripheralID)
    }

    // MARK: - Private Methods

    private func connectAndReadBattery(_ peripheral: CBPeripheral) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: HeyCyanError.unknownDevice)
                    return
                }

                self.connectedPeripheral = peripheral
                self.pendingReadContinuations.append(CheckContinuationWrapper(continuation))
                peripheral.delegate = self
                
                if peripheral.state == .connected {
                    peripheral.discoverServices([Self.heyCyanServiceUUID, Self.heyCyanAltServiceUUID])
                } else {
                    self.centralManager?.connect(peripheral, options: nil)
                }
            }
            
            // Timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                self?.queue.async {
                    if let wrapper = self?.pendingReadContinuations.first as? CheckContinuationWrapper {
                        self?.pendingReadContinuations.removeAll { ($0 as? CheckContinuationWrapper) === wrapper }
                        wrapper.continuation.resume(throwing: HeyCyanError.timeout)
                    }
                }
            }
        }
    }

    private func handleBatteryValue(_ data: Data) {
        // HeyCyan battery response parsing
        // Based on SDK: battery level is typically at a specific byte offset
        // Try to parse as single byte first (0-100 range)
        if data.count >= 1 {
            let level = Int(data[0])
            if level <= 100 {
                batteryLevel = level
                resumePendingReads(with: level)
                return
            }
        }
        
        // Try little-endian uint16
        if data.count >= 2 {
            let level = Int(data[0]) | (Int(data[1]) << 8)
            if level <= 100 {
                batteryLevel = level
                resumePendingReads(with: level)
                return
            }
        }
    }

    private func resumePendingReads(with level: Int) {
        while !pendingReadContinuations.isEmpty {
            let wrapper = pendingReadContinuations.removeFirst() as? CheckContinuationWrapper
            wrapper?.continuation.resume(returning: level)
        }
    }

    private func resumePendingReads(with error: Error) {
        while !pendingReadContinuations.isEmpty {
            let wrapper = pendingReadContinuations.removeFirst() as? CheckContinuationWrapper
            wrapper?.continuation.resume(throwing: error)
        }
    }
}

// MARK: - Helper type for continuation storage

private class CheckContinuationWrapper {
    let continuation: CheckedContinuation<Int, Error>
    init(_ continuation: CheckedContinuation<Int, Error>) {
        self.continuation = continuation
    }
}

// MARK: - CBCentralManagerDelegate

extension HeyCyanService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // State updated
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
            self?.deviceName = peripheral.name
            self?.deviceIdentifier = peripheral.identifier
        }
        peripheral.discoverServices([Self.heyCyanServiceUUID, Self.heyCyanAltServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        resumePendingReads(with: HeyCyanError.connectionFailed(error?.localizedDescription ?? "unknown"))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
        }
        if error != nil {
            resumePendingReads(with: HeyCyanError.connectionFailed("Disconnected"))
        }
    }
}

// MARK: - CBPeripheralDelegate

extension HeyCyanService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            resumePendingReads(with: HeyCyanError.sdkNotAvailable)
            return
        }

        for service in services {
            if service.uuid == Self.heyCyanServiceUUID || service.uuid == Self.heyCyanAltServiceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
                return
            }
        }
        
        // Service not found, try discovering all characteristics
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }

        for char in characteristics {
            // Check if this is a readable characteristic
            if char.properties.contains(.read) {
                batteryCharacteristic = char
                peripheral.readValue(for: char)
                return
            }
            
            // Check for notify characteristic
            if char.properties.contains(.notify) {
                batteryCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        handleBatteryValue(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.isNotifying {
            peripheral.readValue(for: characteristic)
        }
    }
}

// MARK: - Errors

enum HeyCyanError: LocalizedError {
    case deviceNotConnected
    case bluetoothUnavailable
    case deviceNotFound
    case sdkNotAvailable
    case connectionFailed(String)
    case timeout
    case unknownDevice

    var errorDescription: String? {
        switch self {
        case .deviceNotConnected: return "HeyCyan device not connected"
        case .bluetoothUnavailable: return "Bluetooth is not available"
        case .deviceNotFound: return "HeyCyan device not found"
        case .sdkNotAvailable: return "HeyCyan service not found on device"
        case .connectionFailed(let m): return "Connection failed: \(m)"
        case .timeout: return "Battery read timed out"
        case .unknownDevice: return "Device not recognized as HeyCyan"
        }
    }
}
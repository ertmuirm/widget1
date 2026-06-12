import Foundation
import CoreBluetooth

enum BLECommandError: LocalizedError {
    case bluetoothUnavailable
    case deviceNotFound
    case connectionFailed(String)
    case characteristicNotFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:    return "Bluetooth is unavailable"
        case .deviceNotFound:          return "Device not found — make sure the watch is nearby and awake"
        case .connectionFailed(let m): return "Connection failed: \(m)"
        case .characteristicNotFound:  return "Write characteristic not found on device"
        case .timeout:                 return "Operation timed out"
        }
    }
}

/// Self-contained BLE executor for use from App Intents.
/// Creates its own CBCentralManager, connects to a specific peripheral by UUID,
/// writes a hex command sequence, then disconnects. Designed for one-shot use.
final class BLECommandExecutor: NSObject {

    private let queue = DispatchQueue(label: "com.ioswidget.ble-executor", qos: .userInitiated)
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?

    private var targetPeripheralID: UUID?
    private var targetCharUUID: CBUUID?
    private var hexSequence: [String] = []

    private var continuation: CheckedContinuation<Void, Error>?
    private var scanTimeoutWork: DispatchWorkItem?
    private var scanTimeout: TimeInterval = 10
    private var didWrite = false
    private var pendingServiceCount = 0
    private var discoveredServiceCount = 0

    private let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FFF0"),
        CBUUID(string: "FFE0"),
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9F"),
    ]

    func execute(peripheralID: UUID, writeCharUUID: String, hexSequence: [String],
                 timeout: TimeInterval = 10) async throws {
        targetPeripheralID = peripheralID
        targetCharUUID = CBUUID(string: writeCharUUID)
        self.hexSequence = hexSequence
        self.scanTimeout = max(0, timeout)
        didWrite = false
        pendingServiceCount = 0
        discoveredServiceCount = 0

        try await withCheckedThrowingContinuation { [self] (cont: CheckedContinuation<Void, Error>) in
            continuation = cont
            central = CBCentralManager(delegate: self, queue: queue,
                                       options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }

    // Must be called on self.queue.
    private func resume(_ result: Result<Void, Error>) {
        scanTimeoutWork?.cancel()
        scanTimeoutWork = nil
        let cont = continuation
        continuation = nil
        cont?.resume(with: result)
    }

    private func writeAndDisconnect() {
        guard !didWrite else { return }
        guard let p = peripheral, let charUUID = targetCharUUID else {
            resume(.failure(BLECommandError.characteristicNotFound)); return
        }
        var found: CBCharacteristic?
        for svc in p.services ?? [] {
            if let c = svc.characteristics?.first(where: { $0.uuid == charUUID }) { found = c; break }
        }
        guard let char = found else {
            resume(.failure(BLECommandError.characteristicNotFound)); return
        }
        didWrite = true
        let packets = hexSequence.compactMap { hex -> Data? in
            Data(hexString: hex.replacingOccurrences(of: " ", with: ""))
        }
        for (i, data) in packets.enumerated() {
            queue.asyncAfter(deadline: .now() + .milliseconds(i * 50)) { [weak p] in
                p?.writeValue(data, for: char, type: .withoutResponse)
            }
        }
        let disconnectDelay = DispatchTimeInterval.milliseconds(packets.count * 50 + 350)
        queue.asyncAfter(deadline: .now() + disconnectDelay) { [weak self] in
            guard let self, let p = self.peripheral else { return }
            self.central?.cancelPeripheralConnection(p)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECommandExecutor: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            resume(.failure(BLECommandError.bluetoothUnavailable)); return
        }
        guard let targetID = targetPeripheralID else {
            resume(.failure(BLECommandError.deviceNotFound)); return
        }
        // Try already-connected peripherals first (no scan, no battery cost).
        let connected = central.retrieveConnectedPeripherals(withServices: knownServiceUUIDs)
        if let found = connected.first(where: { $0.identifier == targetID }) {
            found.delegate = self
            peripheral = found
            central.connect(found, options: nil)
            return
        }
        // Also try retrieve by identifier (cached from prior sessions).
        let retrieved = central.retrievePeripherals(withIdentifiers: [targetID])
        if let found = retrieved.first {
            found.delegate = self
            peripheral = found
            central.connect(found, options: nil)
            return
        }
        // Fall back to scan. If timeout is 0, skip scan and fail immediately.
        guard scanTimeout > 0 else {
            resume(.failure(BLECommandError.deviceNotFound)); return
        }
        central.scanForPeripherals(withServices: nil, options: nil)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.central?.stopScan()
            self.resume(.failure(BLECommandError.deviceNotFound))
        }
        scanTimeoutWork = work
        queue.asyncAfter(deadline: .now() + scanTimeout, execute: work)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard peripheral.identifier == targetPeripheralID else { return }
        central.stopScan()
        scanTimeoutWork?.cancel()
        scanTimeoutWork = nil
        peripheral.delegate = self
        self.peripheral = peripheral
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
        if didWrite {
            resume(.success(()))
        } else if let error {
            resume(.failure(BLECommandError.connectionFailed(error.localizedDescription)))
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLECommandExecutor: CBPeripheralDelegate {

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
        if let charUUID = targetCharUUID,
           service.characteristics?.first(where: { $0.uuid == charUUID }) != nil {
            writeAndDisconnect()
        } else if discoveredServiceCount == pendingServiceCount && !didWrite {
            resume(.failure(BLECommandError.characteristicNotFound))
        }
    }
}

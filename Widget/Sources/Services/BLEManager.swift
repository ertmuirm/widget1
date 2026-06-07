import Foundation
import CoreBluetooth

// MARK: - Models

struct BLELogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String

    var formattedTimestamp: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: timestamp)
    }
}

struct BLEDeviceInfo: Identifiable {
    let id: UUID          // peripheral.identifier
    let name: String
    var rssi: Int
    let peripheral: CBPeripheral
}

struct BLEServiceInfo: Identifiable {
    var id: String { uuid }
    let uuid: String
    var characteristics: [BLECharInfo]
}

struct BLECharInfo: Identifiable {
    var id: String { uuid }
    let uuid: String
    let properties: CBCharacteristicProperties

    var propertiesString: String {
        var p: [String] = []
        if properties.contains(.read)                 { p.append("Read") }
        if properties.contains(.write)                { p.append("Write") }
        if properties.contains(.writeWithoutResponse) { p.append("WriteNR") }
        if properties.contains(.notify)               { p.append("Notify") }
        if properties.contains(.indicate)             { p.append("Indicate") }
        return p.joined(separator: " · ")
    }
}

// MARK: - BLEManager

final class BLEManager: NSObject, ObservableObject {

    static let shared = BLEManager()

    private let targetFFF1 = CBUUID(string: "0000FFF1-0000-1000-8000-00805F9B34FB")

    // Published state
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var discoveredDevices: [BLEDeviceInfo] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedPeripheral: CBPeripheral?
    @Published var services: [BLEServiceInfo] = []
    @Published var fff1Found = false
    @Published var logEntries: [BLELogEntry] = []
    @Published var isRecordingStream = false
    @Published var streamCountdown = 0

    // Internal
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var fff1Characteristic: CBCharacteristic?
    private var allChars: [CBCharacteristic] = []
    private var streamTimer: Timer?

    enum ConnectionState {
        case disconnected, connecting, connected, failed

        var label: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting:   return "Connecting…"
            case .connected:    return "Connected"
            case .failed:       return "Failed"
            }
        }
    }

    private override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    // MARK: - Scan

    func startScan() {
        guard central.state == .poweredOn else {
            log("Bluetooth not powered on")
            return
        }
        discoveredDevices = []
        isScanning = true
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        log("Scan started")
    }

    func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        log("Scan stopped — \(discoveredDevices.count) device(s) found")
    }

    // MARK: - Connect / Disconnect

    func connect(_ device: BLEDeviceInfo) {
        stopScan()
        services = []
        fff1Characteristic = nil
        fff1Found = false
        allChars = []
        peripheral = device.peripheral
        peripheral?.delegate = self
        connectionState = .connecting
        central.connect(device.peripheral, options: nil)
        log("Connecting to \(device.name) (\(device.id))")
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
    }

    // MARK: - Write to FFF1

    @discardableResult
    func writeHex(_ hex: String) -> Bool {
        let stripped = hex.replacingOccurrences(of: " ", with: "")
        guard let data = Data(hexString: stripped), !data.isEmpty else {
            log("TX failed: invalid hex '\(hex)'")
            return false
        }
        return write(data)
    }

    @discardableResult
    func write(_ data: Data) -> Bool {
        guard let char = fff1Characteristic, let p = peripheral else {
            log("TX failed: FFF1 not available")
            return false
        }
        p.writeValue(data, for: char, type: .withoutResponse)
        log("TX → FFF1: \(data.hexString)")
        return true
    }

    // MARK: - Stream Recording

    func startStreamRecording() {
        streamTimer?.invalidate()
        streamCountdown = 10
        isRecordingStream = true
        log("Stream recording started (10 s)")
        streamTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.streamCountdown -= 1
            if self.streamCountdown <= 0 { self.stopStreamRecording() }
        }
    }

    func stopStreamRecording() {
        streamTimer?.invalidate()
        streamTimer = nil
        isRecordingStream = false
        streamCountdown = 0
        log("Stream recording ended")
    }

    // MARK: - Diagnostics

    func dumpCharacteristics() {
        log("--- Dump Characteristics ---")
        for char in allChars where char.properties.contains(.read) {
            peripheral?.readValue(for: char)
        }
    }

    func subscribeToAll() {
        log("--- Subscribe To All ---")
        for char in allChars {
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                peripheral?.setNotifyValue(true, for: char)
            }
        }
    }

    // MARK: - Export

    func exportText() -> String {
        logEntries.map { "[\($0.formattedTimestamp)] \($0.message)" }.joined(separator: "\n")
    }

    // MARK: - Internal log

    func log(_ message: String) {
        logEntries.append(BLELogEntry(timestamp: Date(), message: message))
    }

    func clearLog() {
        logEntries = []
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        switch central.state {
        case .poweredOn:     log("Bluetooth ready")
        case .poweredOff:    log("Bluetooth off")
        case .unauthorized:  log("Bluetooth unauthorized")
        case .unsupported:   log("Bluetooth unsupported on this device")
        case .resetting:     log("Bluetooth resetting")
        default:             break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Unknown"
        let dev = BLEDeviceInfo(id: peripheral.identifier,
                                name: name,
                                rssi: RSSI.intValue,
                                peripheral: peripheral)
        if let idx = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[idx] = dev
        } else {
            discoveredDevices.append(dev)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        connectedPeripheral = peripheral
        log("Connected — discovering services")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .failed
        log("Connection failed: \(error?.localizedDescription ?? "unknown")")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .disconnected
        connectedPeripheral = nil
        fff1Characteristic = nil
        fff1Found = false
        log("Disconnected\(error != nil ? ": \(error!.localizedDescription)" : "")")
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            log("Service discovery error: \(error.localizedDescription)")
            return
        }
        guard let srvList = peripheral.services else { return }
        log("Discovered \(srvList.count) service(s)")
        for srv in srvList {
            log("Service: \(srv.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: srv)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            log("Char discovery error [\(service.uuid)]: \(error.localizedDescription)")
            return
        }
        guard let chars = service.characteristics else { return }

        var charInfos: [BLECharInfo] = []
        for char in chars {
            let info = BLECharInfo(uuid: char.uuid.uuidString, properties: char.properties)
            charInfos.append(info)
            allChars.append(char)
            log("Char: \(char.uuid.uuidString) [\(info.propertiesString)]")

            if char.uuid == targetFFF1 {
                fff1Characteristic = char
                fff1Found = true
                log("FFF1 Found ✓")
            }

            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: char)
            }
        }

        let srvInfo = BLEServiceInfo(uuid: service.uuid.uuidString, characteristics: charInfos)
        if let idx = services.firstIndex(where: { $0.uuid == srvInfo.uuid }) {
            services[idx] = srvInfo
        } else {
            services.append(srvInfo)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            log("Value error [\(characteristic.uuid)]: \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else { return }
        let hex = data.hexString

        if characteristic.isNotifying {
            log("RX ← \(characteristic.uuid.uuidString): \(hex)")
        } else {
            let ascii = data.printableASCII
            let asciiPart = ascii.isEmpty ? "" : " [\(ascii)]"
            log("READ \(characteristic.uuid.uuidString): \(hex)\(asciiPart)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            log("Write error [\(characteristic.uuid)]: \(error.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            log("Notify error [\(characteristic.uuid)]: \(error.localizedDescription)")
            return
        }
        log("Notify \(characteristic.isNotifying ? "ON" : "OFF"): \(characteristic.uuid.uuidString)")
    }
}

// MARK: - Data helpers

extension Data {
    init?(hexString: String) {
        var hex = hexString.replacingOccurrences(of: " ", with: "")
        guard hex.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        while !hex.isEmpty {
            let prefix = hex.prefix(2)
            hex = String(hex.dropFirst(2))
            guard let byte = UInt8(prefix, radix: 16) else { return nil }
            bytes.append(byte)
        }
        self = Data(bytes)
    }

    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }

    var printableASCII: String {
        String(bytes: filter { $0 >= 32 && $0 < 127 }, encoding: .ascii) ?? ""
    }
}

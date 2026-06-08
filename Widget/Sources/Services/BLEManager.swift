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
    let id: UUID
    var name: String
    var rssi: Int
    var advertisementKeys: [String]
    var localName: String?
    var serviceUUIDs: [String]
    var manufacturerDataLength: Int
    let peripheral: CBPeripheral
    var source: DeviceSource

    enum DeviceSource {
        case scan
        case retrieved         // retrievePeripherals(withIdentifiers:)
        case systemConnected   // retrieveConnectedPeripherals(withServices:)
    }
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
        return p.isEmpty ? "—" : p.joined(separator: " · ")
    }
}

// MARK: - BLEManager

final class BLEManager: NSObject, ObservableObject {

    static let shared = BLEManager()

    private let targetFFF1 = CBUUID(string: "0000FFF1-0000-1000-8000-00805F9B34FB")

    // Service UUIDs commonly seen on Chinese fitness/smartwatch devices.
    // Used for retrieveConnectedPeripherals — must be non-empty.
    private let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FFF0"),  // common custom service (FFF1/FFF2 live here)
        CBUUID(string: "FFE0"),  // alternative custom service
        CBUUID(string: "180D"),  // Heart Rate
        CBUUID(string: "180A"),  // Device Information
        CBUUID(string: "1800"),  // Generic Access
        CBUUID(string: "1801"),  // Generic Attribute
        CBUUID(string: "180F"),  // Battery Service
    ]

    private let storedIdentifiersKey = "ble_prev_connected_ids"

    // MARK: Published state

    @Published var bluetoothState: CBManagerState = .unknown
    @Published var authState: CBManagerAuthorization = .notDetermined
    @Published var isScanning = false
    @Published var scannedDevices: [BLEDeviceInfo] = []
    @Published var retrievedDevices: [BLEDeviceInfo] = []
    @Published var systemConnectedDevices: [BLEDeviceInfo] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedPeripheral: CBPeripheral?
    @Published var services: [BLEServiceInfo] = []
    @Published var fff1Found = false
    @Published var logEntries: [BLELogEntry] = []
    @Published var isRecordingStream = false
    @Published var streamCountdown = 0

    // MARK: Internal

    private var central: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var fff1Characteristic: CBCharacteristic?
    private var allChars: [CBCharacteristic] = []
    private var streamTimer: Timer?
    // Set when startScan() is called before BT is ready; fires scan once poweredOn fires.
    private var pendingScan = false

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
        // queue: nil → CoreBluetooth dispatches delegate callbacks on the main queue.
        // This is the correct documented default and avoids manual DispatchQueue.main
        // wrapping while keeping @Published mutations on the right thread.
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
        authState = CBCentralManager.authorization
    }

    // MARK: - Scan

    func startScan() {
        authState = CBCentralManager.authorization
        guard authState == .allowedAlways else {
            log("⚠️ Bluetooth not authorized (state: \(authorizationLabel)) — cannot scan")
            return
        }
        if central.state != .poweredOn {
            log("Bluetooth not yet ready (state: \(bluetoothStateLabel)) — scan queued, will start when ready")
            pendingScan = true
            return
        }
        pendingScan = false
        scannedDevices = []
        isScanning = true
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        log("Scan started — no service filter, duplicates allowed")

        // Also refresh system-connected list each time scan starts
        refreshSystemConnected()
    }

    func stopScan() {
        pendingScan = false
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        log("Scan stopped — \(scannedDevices.count) device(s) found")
    }

    // MARK: - Previously connected (retrievePeripherals)

    private func loadPreviouslyConnected() {
        let ids = (UserDefaults.standard.stringArray(forKey: storedIdentifiersKey) ?? [])
            .compactMap { UUID(uuidString: $0) }
        guard !ids.isEmpty else {
            log("retrievePeripherals: no stored identifiers")
            return
        }
        log("retrievePeripherals: querying \(ids.count) stored identifier(s)")
        let peripherals = central.retrievePeripherals(withIdentifiers: ids)
        log("retrievePeripherals: returned \(peripherals.count) peripheral(s)")
        retrievedDevices = peripherals.map { makeDeviceInfo($0, source: .retrieved) }
        for d in retrievedDevices { log("  Previously seen: \(d.name) (\(d.id))") }
    }

    func refreshSystemConnected() {
        let peripherals = central.retrieveConnectedPeripherals(withServices: knownServiceUUIDs)
        log("retrieveConnectedPeripherals: \(peripherals.count) system-connected peripheral(s)")
        systemConnectedDevices = peripherals.map { makeDeviceInfo($0, source: .systemConnected) }
        for d in systemConnectedDevices { log("  System-connected: \(d.name) (\(d.id))") }
    }

    private func storeConnectedIdentifier(_ uuid: UUID) {
        var ids = UserDefaults.standard.stringArray(forKey: storedIdentifiersKey) ?? []
        let s = uuid.uuidString
        if !ids.contains(s) {
            ids.append(s)
            UserDefaults.standard.set(ids, forKey: storedIdentifiersKey)
        }
    }

    private func makeDeviceInfo(_ p: CBPeripheral, source: BLEDeviceInfo.DeviceSource) -> BLEDeviceInfo {
        BLEDeviceInfo(id: p.identifier,
                      name: p.name ?? "Unknown",
                      rssi: 0,
                      advertisementKeys: [],
                      localName: nil,
                      serviceUUIDs: [],
                      manufacturerDataLength: 0,
                      peripheral: p,
                      source: source)
    }

    // MARK: - Connect / Disconnect

    func connect(_ device: BLEDeviceInfo) {
        stopScan()
        services = []
        fff1Characteristic = nil
        fff1Found = false
        allChars = []
        activePeripheral = device.peripheral
        activePeripheral?.delegate = self
        connectionState = .connecting
        central.connect(device.peripheral, options: nil)
        log("Connecting to \(device.name) (\(device.id))…")
    }

    func disconnect() {
        if let p = activePeripheral { central.cancelPeripheralConnection(p) }
    }

    // MARK: - Write to FFF1

    @discardableResult
    func writeHex(_ hex: String) -> Bool {
        let stripped = hex.replacingOccurrences(of: " ", with: "")
        guard let data = Data(hexString: stripped), !data.isEmpty else {
            log("TX failed: invalid hex '\(hex)'")
            return false
        }
        return writeData(data)
    }

    @discardableResult
    func writeData(_ data: Data) -> Bool {
        guard let char = fff1Characteristic, let p = activePeripheral else {
            log("TX failed: FFF1 not available")
            return false
        }
        p.writeValue(data, for: char, type: .withoutResponse)
        log("TX → FFF1: \(data.hexString)")
        return true
    }

    // MARK: - Stream recording

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
            activePeripheral?.readValue(for: char)
        }
    }

    func subscribeToAll() {
        log("--- Subscribe To All ---")
        for char in allChars {
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                activePeripheral?.setNotifyValue(true, for: char)
            }
        }
    }

    // MARK: - Export

    func exportText() -> String {
        logEntries.map { "[\($0.formattedTimestamp)] \($0.message)" }.joined(separator: "\n")
    }

    func log(_ message: String) {
        logEntries.append(BLELogEntry(timestamp: Date(), message: message))
    }

    func clearLog() { logEntries = [] }

    // MARK: - State label helpers

    var bluetoothStateLabel: String {
        switch bluetoothState {
        case .unknown:      return "Unknown"
        case .resetting:    return "Resetting"
        case .unsupported:  return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff:   return "Powered Off"
        case .poweredOn:    return "Powered On ✓"
        @unknown default:   return "Unknown(\(bluetoothState.rawValue))"
        }
    }

    var authorizationLabel: String {
        switch authState {
        case .notDetermined: return "Not Determined"
        case .restricted:    return "Restricted"
        case .denied:        return "Denied — open Settings to allow"
        case .allowedAlways: return "Allowed ✓"
        @unknown default:    return "Unknown"
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        authState = CBCentralManager.authorization
        log("centralManagerDidUpdateState: \(bluetoothStateLabel) | auth: \(authorizationLabel)")

        if central.state == .poweredOn {
            loadPreviouslyConnected()
            refreshSystemConnected()
            if pendingScan { startScan() }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Unknown"
        let localName    = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?
                               .map { $0.uuidString } ?? []
        let mfrData      = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let adKeys       = advertisementData.keys.sorted()

        // Verbose discovery log
        var parts = [
            "didDiscover: \(name)",
            peripheral.identifier.uuidString,
            "RSSI:\(RSSI)",
        ]
        if !serviceUUIDs.isEmpty { parts.append("services:[\(serviceUUIDs.joined(separator:","))]") }
        if let mfr = mfrData, !mfr.isEmpty { parts.append("mfr:\(mfr.count)B(\(mfr.hexString))") }
        if let ln = localName { parts.append("localName:\(ln)") }
        if !adKeys.isEmpty { parts.append("adKeys:[\(adKeys.joined(separator:","))]") }
        log(parts.joined(separator: " | "))

        let dev = BLEDeviceInfo(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            advertisementKeys: adKeys,
            localName: localName,
            serviceUUIDs: serviceUUIDs,
            manufacturerDataLength: mfrData?.count ?? 0,
            peripheral: peripheral,
            source: .scan
        )
        if let idx = scannedDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            scannedDevices[idx] = dev
        } else {
            scannedDevices.append(dev)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        connectedPeripheral = peripheral
        storeConnectedIdentifier(peripheral.identifier)
        log("Connected to \(peripheral.name ?? peripheral.identifier.uuidString)")
        log("Discovering all services…")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .failed
        log("Failed to connect: \(error?.localizedDescription ?? "unknown error")")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .disconnected
        connectedPeripheral = nil
        fff1Characteristic = nil
        fff1Found = false
        if let error {
            log("Disconnected with error: \(error.localizedDescription)")
        } else {
            log("Disconnected from \(peripheral.name ?? peripheral.identifier.uuidString)")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { log("Service discovery error: \(error.localizedDescription)"); return }
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
        if let error { log("Char discovery error [\(service.uuid)]: \(error.localizedDescription)"); return }
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
        if let error { log("Value error [\(characteristic.uuid)]: \(error.localizedDescription)"); return }
        guard let data = characteristic.value else { return }
        if characteristic.isNotifying {
            log("RX ← \(characteristic.uuid.uuidString): \(data.hexString)")
        } else {
            let ascii = data.printableASCII
            log("READ \(characteristic.uuid.uuidString): \(data.hexString)\(ascii.isEmpty ? "" : " [\(ascii)]")")
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error { log("Write error [\(characteristic.uuid)]: \(error.localizedDescription)") }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error { log("Notify error [\(characteristic.uuid)]: \(error.localizedDescription)"); return }
        log("Notify \(characteristic.isNotifying ? "ON" : "OFF"): \(characteristic.uuid.uuidString)")
    }
}

// MARK: - Data extensions

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

    var hexString: String { map { String(format: "%02X", $0) }.joined() }

    var printableASCII: String {
        String(bytes: filter { $0 >= 32 && $0 < 127 }, encoding: .ascii) ?? ""
    }
}

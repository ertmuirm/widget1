import Foundation
import CoreBluetooth

// MARK: - Log entry

enum BLELogCategory: String {
    case conn  = "CONN"
    case rx    = "RX"
    case tx    = "TX"
    case state = "STATE"
    case error = "ERR"
    case info  = "INFO"
}

struct BLELogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    var category: BLELogCategory = .info

    var formattedTimestamp: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: timestamp)
    }
}

// MARK: - Device models

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

    enum DeviceSource { case scan, retrieved, systemConnected }
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

// MARK: - Writable characteristic (write target selector)

struct BLEWritableChar: Identifiable, Equatable {
    var id: String { serviceUUID + "." + uuid }
    let serviceUUID: String
    let uuid: String
    let characteristic: CBCharacteristic
    let supportsWithoutResponse: Bool

    var shortLabel: String { String(uuid.prefix(8)) + "…" }

    var writeType: CBCharacteristicWriteType {
        supportsWithoutResponse ? .withoutResponse : .withResponse
    }

    static func == (lhs: BLEWritableChar, rhs: BLEWritableChar) -> Bool { lhs.id == rhs.id }
}

// MARK: - Watch state snapshot

struct WatchStateSnapshot: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sourceCharUUID: String
    let bytes: [UInt8]
    let changedIndices: Set<Int>   // relative to previous snapshot

    /// Byte indices that differ between two states.
    static func diff(previous: [UInt8]?, current: [UInt8]) -> Set<Int> {
        guard let prev = previous else { return [] }
        var changed = Set<Int>()
        let maxLen = max(prev.count, current.count)
        for i in 0..<maxLen {
            let a: UInt8 = i < prev.count    ? prev[i]    : 0
            let b: UInt8 = i < current.count ? current[i] : 0
            if a != b { changed.insert(i) }
        }
        return changed
    }

    /// Human-readable row for each byte.
    var byteRows: [(index: Int, hex: String, ascii: Character?)] {
        bytes.enumerated().map { i, byte in
            let ascii: Character? = (byte >= 32 && byte < 127) ? Character(Unicode.Scalar(byte)) : nil
            return (i, String(format: "%02X", byte), ascii)
        }
    }
}

// MARK: - BLEManager

final class BLEManager: NSObject, ObservableObject {

    static let shared = BLEManager()

    // State restoration identifier for background persistence
    private let centralManagerRestoreIdentifier = "com.ioswidget.blemanager.restoration"

    // Battery Service UUID (standard BLE Battery Service)
    static let batteryServiceUUID = CBUUID(string: "180F")
    static let batteryCharacteristicUUID = CBUUID(string: "2A19")

    private let targetFFF1 = CBUUID(string: "0000FFF1-0000-1000-8000-00805F9B34FB")

    private let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FFF0"), CBUUID(string: "FFE0"),
        CBUUID(string: "180D"), CBUUID(string: "180A"),
        CBUUID(string: "1800"), CBUUID(string: "1801"),
        CBUUID(string: "180F"),
        CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9F"),
    ]

    private let storedIdentifiersKey = "ble_prev_connected_ids"

    // State
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

    // Write target
    @Published var writableChars: [BLEWritableChar] = []
    @Published var selectedWriteTarget: BLEWritableChar?

    // Watch state parser
    @Published var watchStateHistory: [WatchStateSnapshot] = []

    private var central: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var allChars: [CBCharacteristic] = []
    private var streamTimer: Timer?
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
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBCentralManagerOptionRestoreIdentifierKey: centralManagerRestoreIdentifier
        ]
        central = CBCentralManager(delegate: self, queue: nil, options: options)
        authState = CBCentralManager.authorization
    }

    // MARK: - Scan

    func startScan() {
        authState = CBCentralManager.authorization
        guard authState == .allowedAlways else {
            log("⚠️ Bluetooth not authorized (\(authorizationLabel))", category: .error)
            return
        }
        guard central.state == .poweredOn else {
            log("Bluetooth not ready (\(bluetoothStateLabel)) — scan queued", category: .info)
            pendingScan = true
            return
        }
        pendingScan = false
        scannedDevices = []
        isScanning = true
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        log("Scan started — withServices:nil, duplicates allowed", category: .conn)
        refreshSystemConnected()
    }

    func stopScan() {
        pendingScan = false
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        log("Scan stopped — \(scannedDevices.count) device(s) found", category: .conn)
    }

    // MARK: - Previously connected

    private func loadPreviouslyConnected() {
        let ids = (UserDefaults.standard.stringArray(forKey: storedIdentifiersKey) ?? [])
            .compactMap { UUID(uuidString: $0) }
        guard !ids.isEmpty else { log("retrievePeripherals: no stored identifiers"); return }
        log("retrievePeripherals: querying \(ids.count) identifier(s)")
        let peripherals = central.retrievePeripherals(withIdentifiers: ids)
        log("retrievePeripherals: returned \(peripherals.count) peripheral(s)")
        retrievedDevices = peripherals.map { makeDeviceInfo($0, source: .retrieved) }
    }

    func refreshSystemConnected() {
        // Try multiple service UUID sets for Cloud Battery approach
        let batteryServiceUUIDs: [CBUUID] = [BLEManager.batteryServiceUUID]
        let extendedServiceUUIDs: [CBUUID] = [
            BLEManager.batteryServiceUUID,
            CBUUID(string: "180A"),  // Device Information
            CBUUID(string: "1800"),  // Generic Access
            CBUUID(string: "180D"),  // Heart Rate
            CBUUID(string: "1801"),  // Generic Attribute
        ]

        let batteryPeripherals = central.retrieveConnectedPeripherals(withServices: batteryServiceUUIDs)
        log("retrieveConnectedPeripherals (Battery Service): \(batteryPeripherals.count) peripheral(s)")

        let extendedPeripherals = central.retrieveConnectedPeripherals(withServices: extendedServiceUUIDs)
        log("retrieveConnectedPeripherals (extended services): \(extendedPeripherals.count) peripheral(s)")

        let knownPeripherals = central.retrieveConnectedPeripherals(withServices: knownServiceUUIDs)
        log("retrieveConnectedPeripherals (known services): \(knownPeripherals.count) peripheral(s)")

        // Also try retrieving from saved device identifiers - these might be cached
        // even if not returned by retrieveConnectedPeripherals
        var cachedConnectedPeripherals: [CBPeripheral] = []
        let savedIDs = (UserDefaults.standard.stringArray(forKey: storedIdentifiersKey) ?? [])
            .compactMap { UUID(uuidString: $0) }
        if !savedIDs.isEmpty {
            let cachedPeripherals = central.retrievePeripherals(withIdentifiers: savedIDs)
            log("retrievePeripherals (cached): \(cachedPeripherals.count) peripheral(s)")
            
            // Check which cached peripherals are actually connected
            for p in cachedPeripherals {
                if p.state == .connected {
                    cachedConnectedPeripherals.append(p)
                    log("  Cached & connected: \(p.name ?? "Unknown") (\(p.identifier))", category: .conn)
                }
            }
        }

        // Combine and deduplicate
        var seen = Set<UUID>()
        var all: [BLEDeviceInfo] = []

        for p in batteryPeripherals + extendedPeripherals + knownPeripherals {
            if !seen.contains(p.identifier) {
                seen.insert(p.identifier)
                let info = makeDeviceInfo(p, source: .systemConnected)
                all.append(info)
                log("  System-connected: \(info.name) (\(info.id))", category: .conn)
            }
        }

        // Add cached peripherals that are currently connected but not in retrieveConnectedPeripherals
        for p in cachedConnectedPeripherals {
            if !seen.contains(p.identifier) {
                seen.insert(p.identifier)
                let info = makeDeviceInfo(p, source: .systemConnected)
                all.append(info)
                log("  Cached & connected: \(info.name) (\(info.id))", category: .conn)
            }
        }

        systemConnectedDevices = all
    }

    private func storeConnectedIdentifier(_ uuid: UUID) {
        var ids = UserDefaults.standard.stringArray(forKey: storedIdentifiersKey) ?? []
        let s = uuid.uuidString
        if !ids.contains(s) { ids.append(s); UserDefaults.standard.set(ids, forKey: storedIdentifiersKey) }
    }

    private func makeDeviceInfo(_ p: CBPeripheral, source: BLEDeviceInfo.DeviceSource) -> BLEDeviceInfo {
        BLEDeviceInfo(id: p.identifier, name: p.name ?? "Unknown", rssi: 0,
                      advertisementKeys: [], localName: nil, serviceUUIDs: [],
                      manufacturerDataLength: 0, peripheral: p, source: source)
    }

    // MARK: - Connect / Disconnect

    func connect(_ device: BLEDeviceInfo) {
        stopScan()
        services = []; allChars = []
        writableChars = []; selectedWriteTarget = nil
        fff1Found = false; watchStateHistory = []
        activePeripheral = device.peripheral
        activePeripheral?.delegate = self

        // Check if device is already connected by the system
        if device.peripheral.state == .connected {
            log("Device \(device.name) already connected by system, using existing connection", category: .conn)
            connectionState = .connected
            connectedPeripheral = device.peripheral
            // Discover all services to show full capabilities
            device.peripheral.discoverServices(nil)
        } else {
            connectionState = .connecting
            central.connect(device.peripheral, options: nil)
            log("Connecting to \(device.name) (\(device.id))…", category: .conn)
        }
    }

    func disconnect() {
        if let p = activePeripheral { central.cancelPeripheralConnection(p) }
    }

    func connect(peripheralID: UUID) {
        // First try retrieving from cache (for saved devices)
        let cachedPeripherals = central.retrievePeripherals(withIdentifiers: [peripheralID])
        if let p = cachedPeripherals.first {
            log("Found peripheral in cache (saved device)", category: .conn)
            connect(makeDeviceInfo(p, source: .retrieved))
            return
        }

        // Extended service UUIDs for Cloud Battery approach
        let extendedServiceUUIDs: [CBUUID] = [
            BLEManager.batteryServiceUUID,
            CBUUID(string: "180A"),
            CBUUID(string: "1800"),
            CBUUID(string: "180D"),
            CBUUID(string: "1801"),
        ]

        // Check system-connected peripherals using extended service UUIDs
        let batteryPeripherals = central.retrieveConnectedPeripherals(withServices: [BLEManager.batteryServiceUUID])
        let extendedPeripherals = central.retrieveConnectedPeripherals(withServices: extendedServiceUUIDs)
        let knownPeripherals = central.retrieveConnectedPeripherals(withServices: knownServiceUUIDs)

        // Combine and find matching peripheral
        for p in batteryPeripherals + extendedPeripherals + knownPeripherals {
            if p.identifier == peripheralID {
                log("Found peripheral in system-connected list, using existing connection", category: .conn)
                connect(makeDeviceInfo(p, source: .systemConnected))
                return
            }
        }

        // Not found anywhere - start scan to try to find it
        log("Peripheral \(peripheralID) not in cache or connected — starting scan", category: .info)
        startScan()
    }

    // MARK: - Battery Service (Cloud Battery approach)

    /// Retrieve peripherals that have the Battery Service from iOS paired device stack.
    /// This bypasses the GATT service hiding filter for system accessories.
    func retrieveBatteryPeripherals() -> [CBPeripheral] {
        let peripherals = central.retrieveConnectedPeripherals(withServices: [BLEManager.batteryServiceUUID])
        log("retrieveBatteryPeripherals: found \(peripherals.count) peripheral(s) with Battery Service", category: .conn)
        return peripherals
    }

    /// Read battery level from a specific peripheral using the Cloud Battery approach.
    /// Uses BLEReadExecutor which handles connection, service discovery, and reading.
    /// Automatically discovers all services and characteristics to find battery value.
    func readBatteryLevel(for peripheralID: UUID) async throws -> Int {
        log("Reading battery level for \(peripheralID)", category: .info)

        // First, try to get from iOS paired device stack
        let batteryPeripherals = retrieveBatteryPeripherals()
        if let p = batteryPeripherals.first(where: { $0.identifier == peripheralID }) {
            log("Found peripheral in iOS paired device stack", category: .conn)
        }

        // Use BLEReadExecutor with empty service/characteristic to trigger auto-discover mode
        // This will scan ALL services and characteristics to find battery-like values
        let executor = BLEReadExecutor()
        let data = try await executor.execute(
            peripheralID: peripheralID,
            serviceUUID: "",  // Empty triggers auto-discover mode
            characteristicUUID: "",  // Empty triggers auto-discover mode
            timeout: 15  // Longer timeout for full discovery
        )

        // Battery level is typically a single byte (0-100)
        guard let level = data.first else {
            throw BLEReadError.readFailed("No data received")
        }
        return Int(level)
    }

    // MARK: - Write (uses selectedWriteTarget)

    @discardableResult
    func writeHex(_ hex: String) -> Bool {
        let stripped = hex.replacingOccurrences(of: " ", with: "")
        guard let data = Data(hexString: stripped), !data.isEmpty else {
            log("TX failed: invalid hex '\(hex)'", category: .error); return false
        }
        return writeData(data)
    }

    func writeHexSequence(_ hexStrings: [String]) {
        for (i, hex) in hexStrings.enumerated() {
            if i == 0 {
                writeHex(hex)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) { [weak self] in
                    self?.writeHex(hex)
                }
            }
        }
    }

    @discardableResult
    func writeData(_ data: Data) -> Bool {
        guard let target = selectedWriteTarget, let p = activePeripheral else {
            log("TX failed: no write target selected", category: .error); return false
        }
        p.writeValue(data, for: target.characteristic, type: target.writeType)
        log("TX → \(target.uuid): \(data.hexString)", category: .tx)
        return true
    }

    // MARK: - Read characteristic

    func readCharacteristic(serviceUUID: String, charUUID: String) async {
        guard let p = activePeripheral else {
            log("Read failed: not connected", category: .error)
            return
        }
        
        let targetServiceUUID = CBUUID(string: serviceUUID)
        let targetCharUUID = CBUUID(string: charUUID)
        
        // Find the characteristic in discovered services
        var foundChar: CBCharacteristic?
        
        // If serviceUUID is provided, search in that specific service
        // Otherwise, search all services for the characteristic
        if !serviceUUID.isEmpty {
            for service in p.services ?? [] {
                if service.uuid == targetServiceUUID {
                    for char in service.characteristics ?? [] {
                        if char.uuid == targetCharUUID {
                            foundChar = char
                            break
                        }
                    }
                }
            }
        } else {
            // Search all services for the characteristic
            for service in p.services ?? [] {
                for char in service.characteristics ?? [] {
                    if char.uuid == targetCharUUID {
                        foundChar = char
                        break
                    }
                }
                if foundChar != nil { break }
            }
        }
        
        guard let char = foundChar else {
            log("Read failed: characteristic \(charUUID) not found", category: .error)
            return
        }
        
        // Read the value - result will come through didUpdateValueFor delegate
        p.readValue(for: char)
        log("READ → \(charUUID): requested", category: .info)
    }

    // MARK: - Watch state parser

    private func handleIncomingPacket(_ data: Data, charUUID: String) {
        let bytes = [UInt8](data)

        // Detect DF 00 4C state broadcast from watch
        if bytes.count >= 4 && bytes[0] == 0xDF && bytes[1] == 0x00 && bytes[2] == 0x4C {
            let prevBytes = watchStateHistory.last?.bytes
            let changed = WatchStateSnapshot.diff(previous: prevBytes, current: bytes)
            let snapshot = WatchStateSnapshot(timestamp: Date(), sourceCharUUID: charUUID,
                                              bytes: bytes, changedIndices: changed)
            watchStateHistory.append(snapshot)

            if changed.isEmpty {
                log("State packet — no change from previous", category: .state)
            } else {
                let diffs = changed.sorted().map { i -> String in
                    let prev = (prevBytes != nil && i < prevBytes!.count)
                        ? String(format: "%02X", prevBytes![i]) : "--"
                    let cur  = String(format: "%02X", bytes[i])
                    return "[\(i)]\(prev)→\(cur)"
                }.joined(separator: " ")
                log("State change: \(diffs)", category: .state)
            }
        }
    }

    // MARK: - Stream recording

    func startStreamRecording() {
        streamTimer?.invalidate()
        streamCountdown = 10; isRecordingStream = true
        log("Stream recording started (10 s)", category: .info)
        streamTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.streamCountdown -= 1
            if self.streamCountdown <= 0 { self.stopStreamRecording() }
        }
    }

    func stopStreamRecording() {
        streamTimer?.invalidate(); streamTimer = nil
        isRecordingStream = false; streamCountdown = 0
        log("Stream recording ended", category: .info)
    }

    // MARK: - Diagnostics

    func dumpCharacteristics() {
        log("--- Dump Characteristics ---", category: .info)
        for char in allChars where char.properties.contains(.read) {
            activePeripheral?.readValue(for: char)
        }
    }

    func subscribeToAll() {
        log("--- Subscribe To All ---", category: .info)
        for char in allChars {
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                activePeripheral?.setNotifyValue(true, for: char)
            }
        }
    }

    // MARK: - Export (structured for analysis)

    func exportText() -> String {
        var out = [String]()
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let device = connectedPeripheral.map { "\($0.name ?? "Unknown") (\($0.identifier))" } ?? "—"

        out.append("=== BLE SESSION ===")
        out.append("Generated : \(now)")
        out.append("Device    : \(device)")
        out.append("BT State  : \(bluetoothStateLabel)")
        out.append("Auth      : \(authorizationLabel)")
        out.append("")

        func section(_ title: String, _ cat: BLELogCategory?) {
            let entries = cat == nil
                ? logEntries
                : logEntries.filter { $0.category == cat }
            guard !entries.isEmpty else { return }
            out.append("=== \(title) ===")
            for e in entries { out.append("[\(e.formattedTimestamp)] \(e.message)") }
            out.append("")
        }

        section("RECEIVED PACKETS (RX)", .rx)
        section("TRANSMITTED COMMANDS (TX)", .tx)
        section("WATCH STATE CHANGES", .state)
        section("CONNECTION EVENTS", .conn)
        section("ERRORS", .error)

        // Watch state snapshots as byte tables
        if !watchStateHistory.isEmpty {
            out.append("=== WATCH STATE SNAPSHOTS ===")
            for snap in watchStateHistory {
                let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
                out.append("[\(f.string(from: snap.timestamp))] \(snap.sourceCharUUID)")
                out.append("IDX  HEX  ASCII  CHANGED")
                for row in snap.byteRows {
                    let mark = snap.changedIndices.contains(row.index) ? " ◄" : ""
                    let asc  = row.ascii.map { String($0) } ?? "."
                    out.append(String(format: "%03d  %@   %-5@%@", row.index, row.hex, asc, mark))
                }
                out.append("")
            }
        }

        section("FULL CHRONOLOGICAL LOG", nil)

        return out.joined(separator: "\n")
    }

    // MARK: - Logging

    func log(_ message: String, category: BLELogCategory = .info) {
        logEntries.append(BLELogEntry(timestamp: Date(), message: message, category: category))
    }

    func clearLog() { logEntries = [] }

    // MARK: - State labels

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
        case .denied:        return "Denied — open Settings"
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
        log("centralManagerDidUpdateState: \(bluetoothStateLabel) | auth: \(authorizationLabel)", category: .conn)
        if central.state == .poweredOn {
            loadPreviouslyConnected()
            refreshSystemConnected()
            if pendingScan { startScan() }
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        log("willRestoreState: restoring from background", category: .conn)
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for p in peripherals {
                log("  Restored peripheral: \(p.name ?? p.identifier.uuidString)", category: .conn)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name        = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        let localName   = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString } ?? []
        let mfrData     = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let adKeys      = advertisementData.keys.sorted()

        var parts = ["didDiscover: \(name)", peripheral.identifier.uuidString, "RSSI:\(RSSI)"]
        if !serviceUUIDs.isEmpty { parts.append("svc:[\(serviceUUIDs.joined(separator:","))]") }
        if let mfr = mfrData, !mfr.isEmpty { parts.append("mfr:\(mfr.count)B(\(mfr.hexString))") }
        if let ln = localName { parts.append("local:\(ln)") }
        log(parts.joined(separator: " | "), category: .info)

        let dev = BLEDeviceInfo(id: peripheral.identifier, name: name, rssi: RSSI.intValue,
                                advertisementKeys: adKeys, localName: localName,
                                serviceUUIDs: serviceUUIDs, manufacturerDataLength: mfrData?.count ?? 0,
                                peripheral: peripheral, source: .scan)
        if let idx = scannedDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            scannedDevices[idx] = dev
        } else {
            scannedDevices.append(dev)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected; connectedPeripheral = peripheral
        storeConnectedIdentifier(peripheral.identifier)
        log("Connected to \(peripheral.name ?? peripheral.identifier.uuidString)", category: .conn)
        // Discover ALL services to show full device capabilities in debug view
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .failed
        log("Failed to connect: \(error?.localizedDescription ?? "unknown")", category: .error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected; connectedPeripheral = nil; fff1Found = false
        if let error {
            log("Disconnected with error: \(error.localizedDescription)", category: .error)
        } else {
            log("Disconnected from \(peripheral.name ?? peripheral.identifier.uuidString)", category: .conn)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { log("Service discovery error: \(error.localizedDescription)", category: .error); return }
        guard let srvs = peripheral.services else { return }
        log("Discovered \(srvs.count) service(s)", category: .conn)
        for srv in srvs { log("Service: \(srv.uuid.uuidString)"); peripheral.discoverCharacteristics(nil, for: srv) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { log("Char discovery error [\(service.uuid)]: \(error.localizedDescription)", category: .error); return }
        guard let chars = service.characteristics else { return }

        var charInfos: [BLECharInfo] = []
        for char in chars {
            let info = BLECharInfo(uuid: char.uuid.uuidString, properties: char.properties)
            charInfos.append(info); allChars.append(char)
            log("Char: \(char.uuid.uuidString) [\(info.propertiesString)]")

            // Track FFF1
            if char.uuid == targetFFF1 { fff1Found = true; log("FFF1 detected") }

            // Build writable list
            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                let wc = BLEWritableChar(
                    serviceUUID: service.uuid.uuidString,
                    uuid: char.uuid.uuidString,
                    characteristic: char,
                    supportsWithoutResponse: char.properties.contains(.writeWithoutResponse)
                )
                writableChars.append(wc)
                // Auto-select: prefer FFF1, else first writable
                if char.uuid == targetFFF1 || selectedWriteTarget == nil {
                    selectedWriteTarget = wc
                }
            }

            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: char)
            }
        }

        let srvInfo = BLEServiceInfo(uuid: service.uuid.uuidString, characteristics: charInfos)
        if let idx = services.firstIndex(where: { $0.uuid == srvInfo.uuid }) { services[idx] = srvInfo }
        else { services.append(srvInfo) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("Value error [\(characteristic.uuid)]: \(error.localizedDescription)", category: .error); return }
        guard let data = characteristic.value else { return }
        let uuid = characteristic.uuid.uuidString
        if characteristic.isNotifying {
            log("RX ← \(uuid): \(data.hexString)", category: .rx)
            handleIncomingPacket(data, charUUID: uuid)
        } else {
            let ascii = data.printableASCII
            log("READ \(uuid): \(data.hexString)\(ascii.isEmpty ? "" : " [\(ascii)]")", category: .info)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("Write error [\(characteristic.uuid)]: \(error.localizedDescription)", category: .error) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error { log("Notify error [\(characteristic.uuid)]: \(error.localizedDescription)", category: .error); return }
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
            let prefix = hex.prefix(2); hex = String(hex.dropFirst(2))
            guard let byte = UInt8(prefix, radix: 16) else { return nil }
            bytes.append(byte)
        }
        self = Data(bytes)
    }
    var hexString: String { map { String(format: "%02X", $0) }.joined() }
    var printableASCII: String { String(bytes: filter { $0 >= 32 && $0 < 127 }, encoding: .ascii) ?? "" }
}

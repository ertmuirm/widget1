import SwiftUI
import CoreBluetooth

struct BLEDebugView: View {
    @ObservedObject private var ble = BLEManager.shared
    @State private var hexInput = ""
    @State private var showExportSheet = false
    @State private var exportText = ""

    private let presets: [(label: String, category: String, hex: String)] = [
        ("Vibration A",    "Vibration",    "df0006f1020108000100"),
        ("Vibration B",    "Vibration",    "df0006f2020108000101"),
        ("DND A",          "DND",          "df0006f3050106000101"),
        ("DND B",          "DND",          "df0006f2050106000100"),
        ("Notification A", "Notification", "df0006f502010b000101"),
        ("Notification B", "Notification", "df0006fb130101000100"),
    ]

    var body: some View {
        List {
            diagnosticsSection
            systemConnectedSection
            retrievedSection
            scanSection
            if ble.connectionState == .connected || ble.connectionState == .connecting {
                connectionInfoSection
            }
            if ble.connectionState == .connected {
                fff1Section
                servicesSection
                senderSection
                presetsSection
                streamSection
            }
            logSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("BLE Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showExportSheet) {
            BLEExportSheet(text: exportText)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    exportText = ble.exportText()
                    showExportSheet = true
                } label: {
                    Label("Export BLE Log", systemImage: "square.and.arrow.up")
                }
                Button {
                    ble.dumpCharacteristics()
                } label: {
                    Label("Dump Characteristics", systemImage: "doc.text.magnifyingglass")
                }
                Button {
                    ble.subscribeToAll()
                } label: {
                    Label("Subscribe To All", systemImage: "bell.badge")
                }
                Button {
                    ble.refreshSystemConnected()
                } label: {
                    Label("Refresh Connected", systemImage: "arrow.clockwise")
                }
                if ble.connectionState == .connected || ble.connectionState == .connecting {
                    Divider()
                    Button(role: .destructive) {
                        ble.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            DiagRow(label: "Bluetooth State",  value: ble.bluetoothStateLabel,
                    color: ble.bluetoothState == .poweredOn ? .green : .red)
            DiagRow(label: "Authorization",    value: ble.authorizationLabel,
                    color: ble.authState == .allowedAlways ? .green : .orange)
            DiagRow(label: "Scanning",         value: ble.isScanning ? "Active" : "Stopped",
                    color: ble.isScanning ? .green : .secondary)
            DiagRow(label: "Devices Found",    value: "\(ble.scannedDevices.count) scanned · \(ble.systemConnectedDevices.count) system-connected · \(ble.retrievedDevices.count) retrieved",
                    color: .secondary)
            DiagRow(label: "Connection",       value: ble.connectionState.label,
                    color: connectionStateColor)

            if ble.authState == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - System Connected (peripherals already connected to any app on this iPhone)

    private var systemConnectedSection: some View {
        Section {
            if ble.systemConnectedDevices.isEmpty {
                Text("None found — tap ⋯ → Refresh Connected to check")
                    .foregroundStyle(.secondary)
                    .italic()
                    .font(.caption)
            } else {
                ForEach(ble.systemConnectedDevices) { device in
                    DeviceRow(device: device, badge: "System") { ble.connect(device) }
                }
            }
        } header: {
            HStack {
                Text("System-Connected Peripherals")
                Spacer()
                Text("(via Laxasfit / other app)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Peripherals already connected to this iPhone by another app. If your watch is paired with Laxasfit, it should appear here.")
                .font(.caption)
        }
    }

    // MARK: - Previously Retrieved

    private var retrievedSection: some View {
        Section {
            if ble.retrievedDevices.isEmpty {
                Text("None — connect to a device first to store its identifier")
                    .foregroundStyle(.secondary)
                    .italic()
                    .font(.caption)
            } else {
                ForEach(ble.retrievedDevices) { device in
                    DeviceRow(device: device, badge: "Cached") { ble.connect(device) }
                }
            }
        } header: {
            Text("Previously Connected")
        } footer: {
            Text("Peripherals this app has connected to before, retrieved by stored UUID without scanning.")
                .font(.caption)
        }
    }

    // MARK: - Live Scan

    private var scanSection: some View {
        Section {
            HStack {
                if ble.isScanning {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.75)
                        Text("Scanning…").foregroundStyle(.secondary)
                    }
                } else {
                    Text(ble.scannedDevices.isEmpty ? "No devices found" : "\(ble.scannedDevices.count) device(s)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if ble.isScanning {
                    Button("Stop") { ble.stopScan() }
                        .buttonStyle(.bordered).tint(.red)
                } else {
                    Button("Scan") { ble.startScan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(ble.bluetoothState != .poweredOn || ble.authState != .allowedAlways)
                }
            }

            ForEach(ble.scannedDevices.sorted { $0.rssi > $1.rssi }) { device in
                ExpandableDeviceRow(device: device) { ble.connect(device) }
            }
        } header: {
            Text("BLE Scan (no service filter)")
        } footer: {
            Text("Scans with withServices: nil so all advertising peripherals are shown, including those without known service UUIDs.")
                .font(.caption)
        }
    }

    // MARK: - Connection Info

    private var connectionInfoSection: some View {
        Section("Connection") {
            if let p = ble.connectedPeripheral {
                LabeledContent("Name", value: p.name ?? "Unknown")
                LabeledContent("Identifier") {
                    Text(p.identifier.uuidString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                LabeledContent("State", value: ble.connectionState.label)
                    .foregroundStyle(connectionStateColor)
            } else {
                LabeledContent("State", value: ble.connectionState.label)
            }
        }
    }

    // MARK: - FFF1

    private var fff1Section: some View {
        Section("FFF1 Characteristic") {
            HStack(spacing: 10) {
                Image(systemName: ble.fff1Found ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(ble.fff1Found ? .green : .red)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ble.fff1Found ? "FFF1 Found" : "FFF1 Missing")
                        .fontWeight(.semibold)
                        .foregroundStyle(ble.fff1Found ? .green : .red)
                    Text("0000FFF1-0000-1000-8000-00805F9B34FB")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Services & Characteristics

    private var servicesSection: some View {
        Section("Services & Characteristics") {
            if ble.services.isEmpty {
                Text("Discovering…").foregroundStyle(.secondary).italic()
            } else {
                ForEach(ble.services) { service in
                    DisclosureGroup {
                        ForEach(service.characteristics) { char in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(char.uuid)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.white)
                                Text(char.propertiesString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 8).padding(.vertical, 2)
                        }
                    } label: {
                        Text(service.uuid).font(.caption.monospaced())
                    }
                }
            }
        }
    }

    // MARK: - Manual Hex Sender

    private var senderSection: some View {
        Section {
            HStack {
                TextField("df0006f2020108000101", text: $hexInput)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.send)
                    .onSubmit { ble.writeHex(hexInput) }
                Button("Send") { ble.writeHex(hexInput) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!ble.fff1Found || hexInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Manual Hex Sender")
        } footer: {
            Text("ATT Write Command (0x52, withoutResponse) to FFF1")
                .font(.caption)
        }
    }

    // MARK: - Preset Commands

    private var presetsSection: some View {
        Section("Preset Commands") {
            ForEach(presets, id: \.label) { preset in
                Button {
                    if ble.isRecordingStream { ble.stopStreamRecording() }
                    ble.writeHex(preset.hex)
                    ble.startStreamRecording()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.label).foregroundStyle(.white)
                            Text(preset.hex.uppercased()).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(categoryColor(preset.category))
                    }
                }
                .disabled(!ble.fff1Found)
            }
        }
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "Vibration":    return .orange
        case "DND":          return .blue
        case "Notification": return .purple
        default:             return .secondary
        }
    }

    // MARK: - Stream Recorder

    private var streamSection: some View {
        Section {
            HStack(spacing: 10) {
                Circle()
                    .fill(ble.isRecordingStream ? Color.red : Color.gray.opacity(0.4))
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    if ble.isRecordingStream {
                        Text("Recording — \(ble.streamCountdown)s remaining")
                            .foregroundStyle(.red).fontWeight(.medium)
                    } else {
                        Text("Idle").foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if ble.isRecordingStream {
                    Button("Stop") { ble.stopStreamRecording() }
                        .buttonStyle(.bordered).tint(.red).font(.caption)
                }
            }
        } header: {
            Text("Notification Stream Recorder")
        } footer: {
            Text("Records all RX notifications for 10 s after each preset. Helps identify acknowledgement packets even when nothing visible changes on the watch.")
                .font(.caption)
        }
    }

    // MARK: - BLE Log

    private var logSection: some View {
        Section {
            if ble.logEntries.isEmpty {
                Text("No events yet").foregroundStyle(.secondary).italic()
            } else {
                ForEach(ble.logEntries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.formattedTimestamp)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Text(entry.message)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 1)
                }
            }
        } header: {
            HStack {
                Text("BLE Log")
                Spacer()
                if !ble.logEntries.isEmpty {
                    Button("Clear") { ble.clearLog() }
                        .font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Helpers

    private var connectionStateColor: Color {
        switch ble.connectionState {
        case .connected:    return .green
        case .connecting:   return .yellow
        case .failed:       return .red
        case .disconnected: return .secondary
        }
    }
}

// MARK: - Diagnostics Row

private struct DiagRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Device Row (compact, for retrieved/system-connected)

private struct DeviceRow: View {
    let device: BLEDeviceInfo
    let badge: String
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.name).fontWeight(.medium)
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(device.id.uuidString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Connect", action: onConnect)
                .buttonStyle(.borderedProminent).font(.caption)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Expandable Device Row (for scan results, shows ad data)

private struct ExpandableDeviceRow: View {
    let device: BLEDeviceInfo
    let onConnect: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // RSSI strength indicator
                VStack(spacing: 1) {
                    ForEach(0..<4) { bar in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(bar < rssiBarCount ? rssiColor : Color.gray.opacity(0.3))
                            .frame(width: 4, height: CGFloat(4 + bar * 3))
                    }
                }
                .frame(width: 20, height: 20, alignment: .bottom)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text("\(device.rssi) dBm")
                            .font(.caption.monospaced())
                            .foregroundStyle(rssiColor)
                        if !device.serviceUUIDs.isEmpty {
                            Text(device.serviceUUIDs.prefix(2).joined(separator: " "))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        if device.manufacturerDataLength > 0 {
                            Text("mfr:\(device.manufacturerDataLength)B")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Button(action: onConnect) {
                    Text("Connect")
                }.buttonStyle(.borderedProminent).font(.caption)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.id.uuidString)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if let ln = device.localName {
                        Text("Local name: \(ln)").font(.caption2).foregroundStyle(.secondary)
                    }
                    if !device.advertisementKeys.isEmpty {
                        Text("Ad keys: \(device.advertisementKeys.joined(separator: ", "))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !device.serviceUUIDs.isEmpty {
                        Text("Services: \(device.serviceUUIDs.joined(separator: ", "))")
                            .font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 30)
                .padding(.bottom, 6)
            }
        }
    }

    private var rssiBarCount: Int {
        if device.rssi >= -60 { return 4 }
        if device.rssi >= -70 { return 3 }
        if device.rssi >= -80 { return 2 }
        return 1
    }

    private var rssiColor: Color {
        if device.rssi >= -60 { return .green }
        if device.rssi >= -80 { return .yellow }
        return .red
    }
}

// MARK: - Export Sheet

private struct BLEExportSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ble_log_\(Int(Date().timeIntervalSince1970)).txt")
        try? text.data(using: .utf8)?.write(to: url)
        let items: [Any] = FileManager.default.fileExists(atPath: url.path) ? [url] : [text]
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { BLEDebugView() }.preferredColorScheme(.dark)
}

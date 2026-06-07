import SwiftUI
import CoreBluetooth

struct BLEDebugView: View {
    @ObservedObject private var ble = BLEManager.shared
    @State private var hexInput = ""
    @State private var showExportSheet = false
    @State private var exportText = ""

    // Preset commands
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
            scanSection
            if ble.connectionState == .connected {
                deviceInfoSection
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
        .toolbar {
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

                    if ble.connectionState == .connected {
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
        .sheet(isPresented: $showExportSheet) {
            BLEExportSheet(text: exportText)
        }
    }

    // MARK: - Scan Section

    private var scanSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectionStateColor)
                            .frame(width: 8, height: 8)
                        Text(ble.connectionState.label)
                            .fontWeight(.medium)
                    }
                    if ble.bluetoothState != .poweredOn && ble.bluetoothState != .unknown {
                        Text(bluetoothStateLabel)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
                if ble.isScanning {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.75)
                        Button("Stop") { ble.stopScan() }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                } else if ble.connectionState == .disconnected {
                    Button("Scan") { ble.startScan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(ble.bluetoothState != .poweredOn)
                }
            }

            if ble.isScanning && ble.discoveredDevices.isEmpty {
                HStack {
                    Spacer()
                    Text("Scanning for devices…")
                        .foregroundStyle(.secondary)
                        .italic()
                    Spacer()
                }
            }

            ForEach(ble.discoveredDevices.sorted { $0.rssi > $1.rssi }) { device in
                BLEDeviceRow(device: device) {
                    ble.connect(device)
                }
            }
        } header: {
            Text("Device Scanner")
        }
    }

    // MARK: - Connected Device Info

    private var deviceInfoSection: some View {
        Section("Connected Device") {
            if let p = ble.connectedPeripheral {
                LabeledContent("Name", value: p.name ?? "Unknown")
                LabeledContent("Identifier", value: p.identifier.uuidString)
                    .font(.caption.monospaced())
            }
        }
    }

    // MARK: - FFF1 Status

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
                Text("Discovering…")
                    .foregroundStyle(.secondary)
                    .italic()
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
                            .padding(.leading, 8)
                            .padding(.vertical, 2)
                        }
                    } label: {
                        Text(service.uuid)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Manual Hex Sender

    private var senderSection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    TextField("df0006f2020108000101", text: $hexInput)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.send)
                        .onSubmit { sendHex() }

                    Button("Send", action: sendHex)
                        .buttonStyle(.borderedProminent)
                        .disabled(!ble.fff1Found || hexInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        } header: {
            Text("Manual Hex Sender")
        } footer: {
            Text("Sends as ATT Write Command (0x52, withoutResponse) to FFF1")
                .font(.caption)
        }
    }

    private func sendHex() {
        let trimmed = hexInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        ble.writeHex(trimmed)
    }

    // MARK: - Preset Buttons

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
                            Text(preset.label)
                                .foregroundStyle(.white)
                            Text(preset.hex.uppercased())
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
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
                ZStack {
                    Circle()
                        .fill(ble.isRecordingStream ? Color.red.opacity(0.3) : Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Circle()
                        .fill(ble.isRecordingStream ? Color.red : Color.gray)
                        .frame(width: 12, height: 12)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if ble.isRecordingStream {
                        Text("Recording — \(ble.streamCountdown)s remaining")
                            .foregroundStyle(.red)
                            .fontWeight(.medium)
                    } else {
                        Text("Idle")
                            .foregroundStyle(.secondary)
                    }
                    Text("Triggered automatically when a preset is sent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if ble.isRecordingStream {
                    Button("Stop") { ble.stopStreamRecording() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .font(.caption)
                }
            }
        } header: {
            Text("Notification Stream Recorder")
        } footer: {
            Text("Records all incoming notifications for 10 s after sending a preset, helping identify acknowledgement packets.")
                .font(.caption)
        }
    }

    // MARK: - BLE Log

    private var logSection: some View {
        Section {
            if ble.logEntries.isEmpty {
                Text("No events yet")
                    .foregroundStyle(.secondary)
                    .italic()
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
                        .font(.caption)
                        .foregroundStyle(.red)
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
        case .disconnected: return .gray
        }
    }

    private var bluetoothStateLabel: String {
        switch ble.bluetoothState {
        case .poweredOff:   return "Bluetooth is off"
        case .unauthorized: return "Bluetooth permission denied"
        case .unsupported:  return "BLE not supported"
        default:            return ""
        }
    }
}

// MARK: - Device Row

private struct BLEDeviceRow: View {
    let device: BLEDeviceInfo
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .fontWeight(.medium)
                Text(device.id.uuidString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(device.rssi) dBm")
                .font(.caption.monospaced())
                .foregroundStyle(rssiColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(rssiColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Button("Connect", action: onConnect)
                .buttonStyle(.bordered)
                .font(.caption)
        }
        .padding(.vertical, 2)
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
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ble_log_\(Int(Date().timeIntervalSince1970)).txt")
        try? text.data(using: .utf8)?.write(to: tmpURL)
        let items: [Any] = FileManager.default.fileExists(atPath: tmpURL.path) ? [tmpURL] : [text]
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        BLEDebugView()
    }
    .preferredColorScheme(.dark)
}

import SwiftUI
import CoreBluetooth

struct BLEDebugView: View {
    @ObservedObject private var ble   = BLEManager.shared
    @ObservedObject private var store = BLEDeviceStore.shared

    @State private var vibrationPresets     = BLEDeviceStore.defaultVibrationPresets
    @State private var notificationPresets  = BLEDeviceStore.defaultNotificationPresets

    @State private var hexInput         = ""
    @State private var showExportSheet  = false
    @State private var exportText       = ""
    @State private var logFilter: BLELogCategory? = nil
    @State private var showStateDetail: WatchStateSnapshot? = nil
    @State private var savedToast       = false

    var body: some View {
        List {
            diagnosticsSection
            savedDevicesSection
            shortcutsSettingsSection
            systemConnectedSection
            scanSection
            if ble.connectionState == .connected || ble.connectionState == .connecting {
                connectionInfoSection
            }
            if ble.connectionState == .connected {
                writeTargetSection
                watchStateSection
                senderSection
                presetSection(title: "Vibration",    presets: $vibrationPresets,    color: .orange)
                presetSection(title: "Notification",  presets: $notificationPresets, color: .green)
                saveDeviceSection
                streamSection
                servicesSection
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
        .sheet(item: $showStateDetail) { snap in
            WatchStateDetailView(snapshot: snap)
        }
        .onChange(of: ble.connectionState) { _, newState in
            guard newState == .connected, let p = ble.connectedPeripheral else { return }
            if let saved = store.device(withID: p.identifier) {
                vibrationPresets    = saved.vibrationPresets
                notificationPresets = saved.notificationPresets
            } else {
                vibrationPresets    = BLEDeviceStore.defaultVibrationPresets
                notificationPresets = BLEDeviceStore.defaultNotificationPresets
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    exportText = ble.exportText(); showExportSheet = true
                } label: { Label("Export Session Log", systemImage: "square.and.arrow.up") }
                Button { ble.dumpCharacteristics() } label: {
                    Label("Dump Characteristics", systemImage: "doc.text.magnifyingglass")
                }
                Button { ble.subscribeToAll() } label: {
                    Label("Subscribe To All", systemImage: "bell.badge")
                }
                Button { ble.refreshSystemConnected() } label: {
                    Label("Refresh System-Connected", systemImage: "arrow.clockwise")
                }
                if ble.connectionState == .connected || ble.connectionState == .connecting {
                    Divider()
                    Button(role: .destructive) { ble.disconnect() } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            DiagRow(label: "Bluetooth",     value: ble.bluetoothStateLabel,
                    color: ble.bluetoothState == .poweredOn ? .green : .red)
            DiagRow(label: "Authorization", value: ble.authorizationLabel,
                    color: ble.authState == .allowedAlways ? .green : .orange)
            DiagRow(label: "Scanning",      value: ble.isScanning ? "Active" : "Stopped",
                    color: ble.isScanning ? .green : .secondary)
            DiagRow(label: "Connection",    value: ble.connectionState.label,
                    color: connectionStateColor)
            if ble.authState == .denied {
                Button("Open Bluetooth Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Saved Devices

    private var savedDevicesSection: some View {
        Section {
            if store.devices.isEmpty {
                Text("No saved devices. Connect a device and tap Save.")
                    .foregroundStyle(.secondary).italic().font(.caption)
            } else {
                ForEach(store.devices) { device in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(device.name).fontWeight(.medium)
                            Text(device.id.uuidString)
                                .font(.caption2.monospaced()).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Text("TX: \(String(device.writeTargetUUID.prefix(8)))…")
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                Text("\(device.vibrationPresets.count + device.notificationPresets.count) presets")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Connect") { ble.connect(peripheralID: device.id) }
                            .buttonStyle(.borderedProminent).font(.caption)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { store.delete(id: device.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Saved Devices")
        } footer: {
            Text("Saved devices retain their write target and preset commands for use in the Shortcuts app.")
                .font(.caption)
        }
    }

    // MARK: - Shortcuts Settings

    private var shortcutsSettingsSection: some View {
        Section {
            Stepper(value: $store.scanTimeoutSeconds, in: 0...60) {
                HStack {
                    Text("Scan timeout")
                    Spacer()
                    Text(store.scanTimeoutSeconds == 0 ? "Off" : "\(store.scanTimeoutSeconds)s")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
            }
        } header: {
            Text("Shortcuts Settings")
        } footer: {
            Text("How long to scan for the watch if it is not already connected. Set to Off to skip scanning — the command will only be sent if the watch is already paired and cached by iOS.")
                .font(.caption)
        }
    }

    // MARK: - System-Connected

    private var systemConnectedSection: some View {
        Section {
            if ble.systemConnectedDevices.isEmpty {
                Text("None — tap ⋯ → Refresh System-Connected")
                    .foregroundStyle(.secondary).italic().font(.caption)
            } else {
                ForEach(ble.systemConnectedDevices) { dev in
                    DeviceRow(device: dev, badge: "System", badgeColor: .blue) { ble.connect(dev) }
                }
            }
        } header: {
            Text("System-Connected")
        } footer: {
            Text("Peripherals the iPhone is already connected to. Connect here if your watch doesn't appear in the scan list.")
                .font(.caption)
        }
    }

    // MARK: - Scan

    private var scanSection: some View {
        Section {
            HStack {
                if ble.isScanning {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.75)
                        Text("Scanning…").foregroundStyle(.secondary)
                    }
                } else {
                    Text(ble.scannedDevices.isEmpty ? "No devices" : "\(ble.scannedDevices.count) found")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if ble.isScanning {
                    Button("Stop") { ble.stopScan() }.buttonStyle(.bordered).tint(.red)
                } else {
                    Button("Scan") { ble.startScan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(ble.bluetoothState != .poweredOn || ble.authState != .allowedAlways)
                }
            }
            ForEach(ble.scannedDevices.sorted { $0.rssi > $1.rssi }) { dev in
                ExpandableDeviceRow(device: dev) { ble.connect(dev) }
            }
        } header: { Text("BLE Scan") }
    }

    // MARK: - Connection Info

    private var connectionInfoSection: some View {
        Section("Connected Device") {
            if let p = ble.connectedPeripheral {
                LabeledContent("Name", value: p.name ?? "Unknown")
                LabeledContent("UUID") {
                    Text(p.identifier.uuidString).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            LabeledContent("State", value: ble.connectionState.label).foregroundStyle(connectionStateColor)
        }
    }

    // MARK: - Write Target

    private var writeTargetSection: some View {
        Section {
            if ble.writableChars.isEmpty {
                Text("No writable characteristics found").foregroundStyle(.secondary).italic()
            } else {
                ForEach(ble.writableChars) { wc in
                    Button { ble.selectedWriteTarget = wc } label: {
                        HStack(spacing: 10) {
                            Image(systemName: ble.selectedWriteTarget == wc
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(ble.selectedWriteTarget == wc ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(wc.uuid).font(.caption.monospaced()).foregroundStyle(.white)
                                Text(wc.serviceUUID).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                Text(wc.supportsWithoutResponse ? "Write Without Response" : "Write With Response")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("Write Target")
        } footer: {
            if let t = ble.selectedWriteTarget {
                Text("Sending to: \(t.uuid) (\(t.supportsWithoutResponse ? "withoutResponse" : "withResponse"))")
                    .font(.caption)
            }
        }
    }

    // MARK: - Watch State Parser

    private var watchStateSection: some View {
        Section {
            if ble.watchStateHistory.isEmpty {
                Text("No DF 00 4C state packets received yet")
                    .foregroundStyle(.secondary).italic().font(.caption)
            } else {
                if let latest = ble.watchStateHistory.last {
                    Button { showStateDetail = latest } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Latest state — \(latest.bytes.count) bytes")
                                    .foregroundStyle(.white).font(.subheadline)
                                Text(latest.bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
                let changes = ble.watchStateHistory.filter { !$0.changedIndices.isEmpty }
                if !changes.isEmpty {
                    ForEach(changes.suffix(5).reversed()) { snap in
                        Button { showStateDetail = snap } label: {
                            HStack(spacing: 8) {
                                Text(snap.formattedTimestamp)
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                                Text(snap.diffSummary)
                                    .font(.caption.monospaced()).foregroundStyle(.orange).lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            HStack {
                Text("Watch State Parser (DF 00 4C)")
                Spacer()
                Text("\(ble.watchStateHistory.count) packet(s)").font(.caption).foregroundStyle(.secondary)
            }
        } footer: {
            Text("Tap any row for full byte table with changed-byte highlighting.").font(.caption)
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
                    .disabled(ble.selectedWriteTarget == nil || hexInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: { Text("Manual Hex Sender") }
        footer: {
            if let t = ble.selectedWriteTarget { Text("Sends to \(t.uuid)").font(.caption) }
        }
    }

    // MARK: - Editable Preset Sections

    @ViewBuilder
    private func presetSection(title: String, presets: Binding<[BLEPreset]>, color: Color) -> some View {
        Section {
            ForEach(presets) { $preset in
                PresetRow(
                    preset: $preset,
                    accentColor: color,
                    onSend: {
                        if ble.isRecordingStream { ble.stopStreamRecording() }
                        ble.writeHexSequence(preset.hexSequence)
                        ble.startStreamRecording()
                    },
                    onDelete: { presets.wrappedValue.removeAll { $0.id == preset.id } }
                )
                .disabled(ble.selectedWriteTarget == nil)
            }
            Button {
                presets.wrappedValue.append(BLEPreset(label: "New Command", hexSequence: [""]))
            } label: {
                Label("Add Preset", systemImage: "plus").font(.subheadline)
            }
        } header: { Text(title) }
    }

    // MARK: - Save Device

    private var saveDeviceSection: some View {
        Section {
            if let p = ble.connectedPeripheral, let target = ble.selectedWriteTarget {
                LabeledContent("Device", value: p.name ?? "Unknown")
                LabeledContent("Write Target") {
                    Text(String(target.uuid.prefix(18)) + "…")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                LabeledContent("Presets",
                    value: "\(vibrationPresets.count) vibration · \(notificationPresets.count) notification")

                Button {
                    let device = SavedBLEDevice(
                        id: p.identifier,
                        name: p.name ?? "Unknown",
                        writeTargetUUID: target.uuid,
                        vibrationPresets: vibrationPresets,
                        notificationPresets: notificationPresets
                    )
                    store.upsert(device)
                    withAnimation { savedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { savedToast = false }
                    }
                } label: {
                    Label("Save Device Configuration", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if savedToast {
                    Label("Saved!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            } else {
                Text("Connect a device to save its configuration.")
                    .foregroundStyle(.secondary).italic().font(.caption)
            }
        } header: { Text("Save to Shortcuts") }
        footer: {
        Text("After saving, find \u{201C}Send Watch Command\u{201D} in the Shortcuts app under this app\u{2019}s actions.")
                .font(.caption)
        }
    }

    // MARK: - Stream Recorder

    private var streamSection: some View {
        Section {
            HStack(spacing: 10) {
                Circle().fill(ble.isRecordingStream ? Color.red : Color.gray.opacity(0.4))
                    .frame(width: 12, height: 12)
                if ble.isRecordingStream {
                    Text("Recording — \(ble.streamCountdown)s").foregroundStyle(.red).fontWeight(.medium)
                } else {
                    Text("Idle — fires automatically on preset send").foregroundStyle(.secondary)
                }
                Spacer()
                if ble.isRecordingStream {
                    Button("Stop") { ble.stopStreamRecording() }
                        .buttonStyle(.bordered).tint(.red).font(.caption)
                }
            }
        } header: { Text("Notification Stream Recorder") }
    }

    // MARK: - Services

    private var servicesSection: some View {
        Section("Services & Characteristics") {
            if ble.services.isEmpty {
                Text("Discovering…").foregroundStyle(.secondary).italic()
            } else {
                ForEach(ble.services) { service in
                    DisclosureGroup {
                        ForEach(service.characteristics) { char in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(char.uuid).font(.caption.monospaced()).foregroundStyle(.white)
                                Text(char.propertiesString).font(.caption2).foregroundStyle(.secondary)
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

    // MARK: - Log

    private var logSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All",   active: logFilter == nil)              { logFilter = nil }
                    FilterChip(label: "RX",    active: logFilter == .rx,    color: .green)  { logFilter = .rx }
                    FilterChip(label: "TX",    active: logFilter == .tx,    color: .blue)   { logFilter = .tx }
                    FilterChip(label: "STATE", active: logFilter == .state, color: .orange) { logFilter = .state }
                    FilterChip(label: "CONN",  active: logFilter == .conn,  color: .purple) { logFilter = .conn }
                    FilterChip(label: "ERR",   active: logFilter == .error, color: .red)    { logFilter = .error }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))

            let filtered = logFilter == nil ? ble.logEntries : ble.logEntries.filter { $0.category == logFilter }
            if filtered.isEmpty {
                Text("No entries").foregroundStyle(.secondary).italic()
            } else {
                ForEach(filtered.reversed()) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.category.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(categoryBadgeColor(entry.category))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.formattedTimestamp)
                                .font(.caption2.monospaced()).foregroundStyle(.secondary)
                            Text(entry.message)
                                .font(.caption.monospaced()).foregroundStyle(.white)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        } header: {
            HStack {
                Text("BLE Log (\(ble.logEntries.count))")
                Spacer()
                Button {
                    exportText = ble.exportText(); showExportSheet = true
                } label: { Label("Export", systemImage: "square.and.arrow.up").font(.caption) }
                Button("Clear") { ble.clearLog() }.font(.caption).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Helpers

    private func categoryBadgeColor(_ cat: BLELogCategory) -> Color {
        switch cat {
        case .rx:    return .green
        case .tx:    return .cyan
        case .state: return .orange
        case .conn:  return .purple
        case .error: return .red
        case .info:  return .secondary
        }
    }

    private var connectionStateColor: Color {
        switch ble.connectionState {
        case .connected:    return .green
        case .connecting:   return .yellow
        case .failed:       return .red
        case .disconnected: return .secondary
        }
    }
}

// MARK: - Preset Row (inline-editable)

private struct PresetRow: View {
    @Binding var preset: BLEPreset
    let accentColor: Color
    let onSend: () -> Void
    let onDelete: () -> Void

    @State private var isEditing  = false
    @State private var editLabel  = ""
    @State private var editHex    = ""

    var body: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Label", text: $editLabel)
                    .font(.body)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hex packets (one per line)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $editHex)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 64)
                        .scrollContentBackground(.hidden)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                HStack(spacing: 12) {
                    Button("Done") { commitEdit() }
                        .buttonStyle(.borderedProminent).font(.caption)
                    Button("Cancel", role: .cancel) { isEditing = false }
                        .font(.caption)
                    Spacer()
                    Button(role: .destructive) { onDelete() } label: {
                        Image(systemName: "trash")
                    }
                    .font(.caption).foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
            .onAppear {
                editLabel = preset.label
                editHex   = preset.hexSequence.joined(separator: "\n")
            }
        } else {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.label).foregroundStyle(.white)
                    if let first = preset.hexSequence.first, !first.isEmpty {
                        Text(first.uppercased()).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    if preset.hexSequence.count > 1 {
                        Text("+ \(preset.hexSequence.count - 1) more packet(s)")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Button { onSend() } label: {
                    Image(systemName: "arrow.up.circle.fill").foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)

                Button { isEditing = true } label: {
                    Image(systemName: "pencil").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commitEdit() {
        let trimmed = editLabel.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { preset.label = trimmed }
        let lines = editHex
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !lines.isEmpty { preset.hexSequence = lines }
        isEditing = false
    }
}

// MARK: - Watch State Detail Sheet

struct WatchStateDetailView: View {
    let snapshot: WatchStateSnapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Timestamp", value: snapshot.formattedTimestamp)
                    LabeledContent("Source", value: snapshot.sourceCharUUID).font(.caption.monospaced())
                    LabeledContent("Bytes", value: "\(snapshot.bytes.count)")
                    if !snapshot.changedIndices.isEmpty {
                        LabeledContent("Changed", value: snapshot.diffSummary).foregroundStyle(.orange)
                    }
                }
                Section("Byte Table") {
                    HStack {
                        Text("IDX").frame(width: 36, alignment: .leading)
                        Text("HEX").frame(width: 36, alignment: .leading)
                        Text("DEC").frame(width: 36, alignment: .leading)
                        Text("CHR").frame(width: 24, alignment: .leading)
                        Text("Δ").frame(width: 16, alignment: .center)
                    }
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)

                    ForEach(snapshot.byteRows, id: \.index) { row in
                        let changed = snapshot.changedIndices.contains(row.index)
                        HStack {
                            Text(String(format: "%03d", row.index)).frame(width: 36, alignment: .leading)
                            Text(row.hex).frame(width: 36, alignment: .leading)
                                .foregroundStyle(changed ? .orange : .white)
                            Text(String(UInt8(row.hex, radix: 16) ?? 0))
                                .frame(width: 36, alignment: .leading).foregroundStyle(.secondary)
                            Text(row.ascii.map { String($0) } ?? "·")
                                .frame(width: 24, alignment: .leading).foregroundStyle(.secondary)
                            Text(changed ? "◄" : "").frame(width: 16, alignment: .center)
                                .foregroundStyle(.orange)
                        }
                        .font(.caption.monospaced())
                        .listRowBackground(changed ? Color.orange.opacity(0.08) : Color.clear)
                    }
                }
                Section("Raw Hex") {
                    Text(snapshot.bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
                        .font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(.white)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Watch State")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Supporting Views

private struct DiagRow: View {
    let label: String; let value: String; var color: Color = .primary
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).font(.subheadline)
            Spacer()
            Text(value).foregroundStyle(color).font(.subheadline).multilineTextAlignment(.trailing)
        }
    }
}

private struct FilterChip: View {
    let label: String; let active: Bool; var color: Color = .secondary; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(active ? color.opacity(0.25) : Color.gray.opacity(0.15))
                .foregroundStyle(active ? color : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? color.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceRow: View {
    let device: BLEDeviceInfo; let badge: String; var badgeColor: Color = .blue; let onConnect: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.name).fontWeight(.medium)
                    Text(badge).font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(badgeColor.opacity(0.2)).foregroundStyle(badgeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(device.id.uuidString).font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Connect", action: onConnect).buttonStyle(.borderedProminent).font(.caption)
        }
        .padding(.vertical, 2)
    }
}

private struct ExpandableDeviceRow: View {
    let device: BLEDeviceInfo; let onConnect: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RSSIBars(rssi: device.rssi)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text("\(device.rssi) dBm").font(.caption.monospaced()).foregroundStyle(rssiColor)
                        if !device.serviceUUIDs.isEmpty {
                            Text(device.serviceUUIDs.prefix(2).joined(separator: " "))
                                .font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        if device.manufacturerDataLength > 0 {
                            Text("mfr:\(device.manufacturerDataLength)B").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Button("Connect", action: onConnect).buttonStyle(.borderedProminent).font(.caption)
                Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.id.uuidString).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    if let ln = device.localName { Text("Local: \(ln)").font(.caption2).foregroundStyle(.secondary) }
                    if !device.advertisementKeys.isEmpty {
                        Text("Ad keys: \(device.advertisementKeys.joined(separator: ", "))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !device.serviceUUIDs.isEmpty {
                        Text("Services: \(device.serviceUUIDs.joined(separator: ", "))")
                            .font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 30).padding(.bottom, 6)
            }
        }
    }

    private var rssiColor: Color { device.rssi >= -60 ? .green : device.rssi >= -80 ? .yellow : .red }
}

private struct RSSIBars: View {
    let rssi: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar < barCount ? barColor : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(5 + bar * 3))
            }
        }
        .frame(width: 22, height: 20, alignment: .bottom)
    }
    private var barCount: Int { rssi >= -60 ? 4 : rssi >= -70 ? 3 : rssi >= -80 ? 2 : 1 }
    private var barColor: Color { rssi >= -60 ? .green : rssi >= -80 ? .yellow : .red }
}

private struct BLEExportSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ble_session_\(Int(Date().timeIntervalSince1970)).txt")
        try? text.data(using: .utf8)?.write(to: url)
        let items: [Any] = FileManager.default.fileExists(atPath: url.path) ? [url] : [text]
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - WatchStateSnapshot extensions

extension WatchStateSnapshot {
    var formattedTimestamp: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: timestamp)
    }
    var diffSummary: String {
        changedIndices.sorted().map { i -> String in
            String(format: "[%d]:%02X", i, i < bytes.count ? bytes[i] : 0)
        }.joined(separator: " ")
    }
}

#Preview {
    NavigationStack { BLEDebugView() }.preferredColorScheme(.dark)
}

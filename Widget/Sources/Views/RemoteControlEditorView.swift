import SwiftUI
import UniformTypeIdentifiers

// MARK: - Row view (shown in WidgetListView)

struct RemoteControlRowView: View {
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("Remote Control")
                    .font(.headline)
                    .foregroundStyle(.white)

                let ssid = SharedStorage.shared.allowedSSID
                if ssid.isEmpty {
                    Text("Tap to configure")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(LocalActionServer.shared.isRunning ? Color.green : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(ssid)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    let count = SharedStorage.shared.loadPushCommandEntries().count
                    Text("\(count) command\(count == 1 ? "" : "s") · port \(SharedStorage.shared.serverPort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Editor view (opened from list row or + menu)

struct RemoteControlEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var ssid: String
    @State private var port: String
    @State private var entries: [PushCommandEntry]
    @State private var editingEntry: PushCommandEntry?
    @State private var showEntryEditor = false
    @State private var isRunning: Bool
    @State private var isReordering = false
    @State private var showShortcutImport = false
    @State private var importAlertMessage: String?

    init() {
        _ssid      = State(initialValue: SharedStorage.shared.allowedSSID)
        _port      = State(initialValue: "\(SharedStorage.shared.serverPort)")
        _entries   = State(initialValue: SharedStorage.shared.loadPushCommandEntries())
        _isRunning = State(initialValue: LocalActionServer.shared.isRunning)
    }

    var body: some View {
        List {
            // Status
            Section {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isRunning ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(isRunning
                         ? "Server running on port \(SharedStorage.shared.serverPort)"
                         : "Server stopped")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Network
            Section {
                TextField("Wi-Fi SSID", text: $ssid)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                HStack {
                    Text("Port")
                    Spacer()
                    TextField("8080", text: $port)
                        .foregroundStyle(.white)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            } header: {
                Text("Network")
            } footer: {
                Text("Server starts automatically when your phone connects to this Wi-Fi network. Leave SSID empty to keep it disabled entirely.")
                    .font(.caption)
            }

            // Commands
            Section {
                ForEach(entries) { entry in
                    Button {
                        editingEntry = entry
                        showEntryEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.label.isEmpty ? entry.command : entry.label)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("id: \(entry.command)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.action.type.displayName +
                                 (entry.action.payload.isEmpty ? "" : ": \(entry.action.payload)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onMove { from, to in entries.move(fromOffsets: from, toOffset: to) }
                .onDelete { indexSet in
                    entries.remove(atOffsets: indexSet)
                    SharedStorage.shared.savePushCommandEntries(entries)
                }

                if !isReordering {
                    Button {
                        editingEntry = nil
                        showEntryEditor = true
                    } label: {
                        Label("Add Command", systemImage: "plus")
                    }
                    .foregroundStyle(.gray)

                    Button {
                        showShortcutImport = true
                    } label: {
                        Label("Import from Shortcut", systemImage: "square.and.arrow.down")
                    }
                    .foregroundStyle(.gray)
                }
            } header: {
                HStack {
                    Text("Commands (\(entries.count))")
                        .textCase(nil)
                    Spacer()
                    if !entries.isEmpty {
                        Button(isReordering ? "Done" : "Reorder") {
                            withAnimation { isReordering.toggle() }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    }
                }
            } footer: {
                let portStr = (Int(port) ?? 0) > 0 ? port : "8080"
                if !ssid.isEmpty {
                    Text("GET http://<phone-ip>:\(portStr)/execute-widget-action?id=COMMAND_ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Remote Control")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .sheet(isPresented: $showEntryEditor) {
            NavigationStack {
                PushCommandEditorView(entry: editingEntry)
            }
        }
        .onChange(of: showEntryEditor) { showing in
            if !showing {
                entries = SharedStorage.shared.loadPushCommandEntries()
            }
        }
        .fileImporter(
            isPresented: $showShortcutImport,
            allowedContentTypes: [UTType(filenameExtension: "shortcut") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleShortcutImport(result)
        }
        .alert("Import", isPresented: Binding(
            get: { importAlertMessage != nil },
            set: { if !$0 { importAlertMessage = nil } }
        )) {
            Button("OK") { importAlertMessage = nil }
        } message: {
            Text(importAlertMessage ?? "")
        }
    }

    private func handleShortcutImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else {
            importAlertMessage = "Could not access file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let items = try ShortcutFileService.importItems(from: data)
            guard !items.isEmpty else {
                importAlertMessage = "No items found in shortcut."
                return
            }
            for item in items {
                let commandID = item.name
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }
                    .joined(separator: "-")
                entries.append(PushCommandEntry(command: commandID, label: item.name, action: item.action))
            }
            SharedStorage.shared.savePushCommandEntries(entries)
            importAlertMessage = "Imported \(items.count) command\(items.count == 1 ? "" : "s")."
        } catch {
            importAlertMessage = error.localizedDescription
        }
    }

    private func save() {
        SharedStorage.shared.allowedSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        if let p = Int(port), p > 0, p < 65536 {
            SharedStorage.shared.serverPort = p
        }
        SharedStorage.shared.savePushCommandEntries(entries)
        LocalActionServer.shared.stop()
        LocalActionServer.shared.start()
        dismiss()
    }
}

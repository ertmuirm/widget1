import SwiftUI

struct PushCommandView: View {
    @State private var entries: [PushCommandEntry] = []
    @State private var editingEntry: PushCommandEntry?
    @State private var showEditor = false

    var body: some View {
        List {
            ForEach(entries) { entry in
                Button {
                    editingEntry = entry
                    showEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.label.isEmpty ? entry.command : entry.label)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("id: \(entry.command)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.action.type.displayName + (entry.action.payload.isEmpty ? "" : ": \(entry.action.payload)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
            }
            .onDelete { indexSet in
                entries.remove(atOffsets: indexSet)
                SharedStorage.shared.savePushCommandEntries(entries)
            }

            Button {
                editingEntry = nil
                showEditor = true
            } label: {
                Label("Add Command", systemImage: "plus")
            }
            .foregroundStyle(.gray)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Command Mappings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar { EditButton() }
        .onAppear {
            entries = SharedStorage.shared.loadPushCommandEntries()
        }
        .sheet(isPresented: $showEditor, onDismiss: {
            entries = SharedStorage.shared.loadPushCommandEntries()
        }) {
            NavigationStack {
                PushCommandEditorView(entry: editingEntry)
            }
        }
    }
}

struct PushCommandEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var command: String
    @State private var label: String
    @State private var action: WidgetAction
    @State private var showActionPicker = false

    private let existingID: UUID?

    init(entry: PushCommandEntry?) {
        existingID = entry?.id
        _command = State(initialValue: entry?.command ?? "")
        _label   = State(initialValue: entry?.label ?? "")
        _action  = State(initialValue: entry?.action ?? WidgetAction())
    }

    private var actionItem: Binding<WidgetItem> {
        Binding(
            get: {
                var item = WidgetItem()
                item.action = action
                return item
            },
            set: { action = $0.action ?? WidgetAction() }
        )
    }

    var body: some View {
        List {
            Section("Command ID") {
                TextField("e.g. open_spotify", text: $command)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section("Label (optional)") {
                TextField("Friendly name", text: $label)
                    .foregroundStyle(.white)
            }
            Section {
                Button {
                    showActionPicker = true
                } label: {
                    HStack {
                        Text("Action Type")
                        Spacer()
                        Text(action.type.displayName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.white)

                switch action.type {
                case .urlScheme:
                    TextField("URL or deep link", text: $action.payload)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                case .shortcut:
                    TextField("Shortcut name", text: $action.payload)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                case .appIntent:
                    TextField("App intent URL", text: $action.payload)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            } header: {
                Text("Action")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(existingID == nil ? "New Command" : "Edit Command")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showActionPicker) {
            ActionPickerView(item: actionItem)
        }
    }

    private func save() {
        var entries = SharedStorage.shared.loadPushCommandEntries()
        let entry = PushCommandEntry(
            id: existingID ?? UUID(),
            command: command.trimmingCharacters(in: .whitespaces),
            label: label.trimmingCharacters(in: .whitespaces),
            action: action
        )
        if let idx = entries.firstIndex(where: { $0.id == existingID }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        SharedStorage.shared.savePushCommandEntries(entries)
        dismiss()
    }
}

import SwiftUI

struct PushCommandView: View {
    @State private var entries: [PushCommandEntry] = SharedStorage.shared.loadPushCommandEntries()
    @State private var editingEntry: PushCommandEntry?
    @State private var showingEditor = false

    var body: some View {
        List {
            Section {
                ForEach(entries) { entry in
                    Button {
                        editingEntry = entry
                        showingEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.command.isEmpty ? "(no command)" : entry.command)
                                .font(.subheadline).foregroundStyle(.white)
                            Text(entry.label.isEmpty ? entry.action.payload : entry.label)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .onDelete(perform: deleteEntries)
            } header: {
                Text("Command Mappings")
            } footer: {
                Text("Each mapping links a command ID (e.g. \"lights_off\") to a widget action. Trigger via GET /execute-widget-action?id=<command>.")
                    .font(.caption2)
            }

            Section {
                Button {
                    let entry = PushCommandEntry()
                    entries.append(entry)
                    SharedStorage.shared.savePushCommandEntries(entries)
                    editingEntry = entry
                    showingEditor = true
                } label: {
                    Label("Add Mapping", systemImage: "plus.circle")
                }
                .foregroundStyle(.blue)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Command Mappings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar { EditButton() }
        .sheet(isPresented: $showingEditor, onDismiss: { editingEntry = nil }) {
            if let entry = editingEntry {
                NavigationStack {
                    PushCommandEditorView(entry: entry) { updated in
                        if let idx = entries.firstIndex(where: { $0.id == updated.id }) {
                            entries[idx] = updated
                        }
                        SharedStorage.shared.savePushCommandEntries(entries)
                        showingEditor = false
                    }
                }
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        SharedStorage.shared.savePushCommandEntries(entries)
    }
}

struct PushCommandEditorView: View {
    @State private var entry: PushCommandEntry
    @State private var showActionPicker = false
    let onSave: (PushCommandEntry) -> Void

    init(entry: PushCommandEntry, onSave: @escaping (PushCommandEntry) -> Void) {
        _entry = State(initialValue: entry)
        self.onSave = onSave
    }

    var body: some View {
        List {
            Section("Identity") {
                HStack {
                    Text("Command ID")
                    Spacer()
                    TextField("e.g. lights_off", text: $entry.command)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                HStack {
                    Text("Label")
                    Spacer()
                    TextField("Optional description", text: $entry.label)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.white)
                }
            }

            Section("Action") {
                Button {
                    showActionPicker = true
                } label: {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(entry.action.type.displayName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.white)

                HStack {
                    Text("Payload")
                    Spacer()
                    TextField("URL or shortcut name", text: $entry.action.payload)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Mapping")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSave(entry) }
            }
        }
        .sheet(isPresented: $showActionPicker) {
            NavigationStack {
                PushActionTypePicker(selected: $entry.action.type)
            }
        }
    }
}

struct PushActionTypePicker: View {
    @Binding var selected: ActionType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(ActionType.allCases, id: \.self) { type in
                Button {
                    selected = type
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName).foregroundStyle(.white)
                            Text(type.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected == type {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Action Type")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

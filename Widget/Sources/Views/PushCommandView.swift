import SwiftUI

// MARK: - Push Command List
// Presented as a NavigationLink destination from SettingsView → Remote Control.

struct PushCommandView: View {
    @State private var entries: [PushCommandEntry] = []

    var body: some View {
        List {
            Section {
                ForEach(entries.indices, id: \.self) { index in
                    NavigationLink {
                        PushCommandEditorView(entry: $entries[index], onChanged: saveEntries)
                    } label: {
                        PushCommandRowView(entry: entries[index])
                    }
                }
                .onDelete { indexSet in
                    entries.remove(atOffsets: indexSet)
                    saveEntries()
                }

                Button {
                    entries.append(PushCommandEntry())
                    saveEntries()
                } label: {
                    Label("Add Command", systemImage: "plus")
                }
                .foregroundStyle(.blue)

            } header: {
                Text("Commands (\(entries.count))")
            } footer: {
                Text("Each command maps a text ID to an action. Trigger with:\nGET http://<iPhone-IP>:<PORT>/execute-widget-action?id=YOUR_COMMAND\nCommands are case-sensitive.")
                    .font(.caption2)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Command Mappings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear { entries = SharedStorage.shared.loadPushCommandEntries() }
    }

    private func saveEntries() { SharedStorage.shared.savePushCommandEntries(entries) }
}

// MARK: - Row

struct PushCommandRowView: View {
    let entry: PushCommandEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.command.isEmpty ? "(no command set)" : entry.command)
                .font(.headline)
                .foregroundStyle(entry.command.isEmpty ? .secondary : .white)
            if !entry.label.isEmpty {
                Text(entry.label).font(.subheadline).foregroundStyle(.secondary)
            }
            let suffix = entry.action.payload.isEmpty ? "" : ": \(entry.action.payload)"
            Text(entry.action.type.displayName + suffix).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor

struct PushCommandEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var entry: PushCommandEntry
    let onChanged: () -> Void
    @State private var showActionTypePicker = false

    var body: some View {
        List {
            Section("Trigger") {
                TextField("Command ID (e.g. kill-bluetooth)", text: $entry.command)
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Label (optional description)", text: $entry.label)
                    .foregroundStyle(.white)
            }
            Section("Action") {
                Button {
                    showActionTypePicker = true
                } label: {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(entry.action.type.displayName).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.white)

                if entry.action.type == .urlScheme {
                    TextField("URL Scheme (e.g. myapp://action)", text: $entry.action.payload)
                        .foregroundStyle(.white).textInputAutocapitalization(.never).autocorrectionDisabled()
                } else {
                    TextField(
                        entry.action.type == .appIntent ? "Intent Name" : "Shortcut Name",
                        text: $entry.action.payload
                    ).foregroundStyle(.white)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Command")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onChanged(); dismiss() }
            }
        }
        .sheet(isPresented: $showActionTypePicker) {
            PushActionTypePicker(selectedType: $entry.action.type)
        }
    }
}

// MARK: - Action Type Picker

struct PushActionTypePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: ActionType

    var body: some View {
        NavigationStack {
            List {
                ForEach(ActionType.allCases, id: \.self) { type in
                    Button {
                        selectedType = type; dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayName).font(.headline).foregroundStyle(.white)
                                Text(type.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if type == selectedType {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Action Type")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

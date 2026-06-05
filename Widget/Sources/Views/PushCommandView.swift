import SwiftUI

// MARK: - Push Command List (main sheet)

struct PushCommandView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [PushCommandEntry] = []
    @State private var lastPollDate: Date?

    private var topic: String { SharedStorage.shared.ntfyTopic }

    var body: some View {
        NavigationStack {
            List {
                ntfySection
                commandsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Push Notification")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { reload() }
        }
    }

    // MARK: - ntfy Topic Section

    private var ntfySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("ntfy Topic", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(alignment: .top, spacing: 8) {
                    Text(topic)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = topic
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 4)

            HStack {
                Text("Publish URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("https://ntfy.sh/\(topic)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(lastPollText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        } header: {
            Text("ntfy.sh Configuration")
        } footer: {
            Text("iOS polls ntfy.sh during background refresh — typically every 15–30 minutes depending on device usage patterns. POST your command as the message body to trigger an action.")
                .font(.caption2)
        }
    }

    // MARK: - Commands Section

    private var commandsSection: some View {
        Section {
            ForEach(entries.indices, id: \.self) { index in
                NavigationLink {
                    PushCommandEditorView(
                        entry: $entries[index],
                        onChanged: saveEntries
                    )
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
            Text("Each command maps one incoming text string to a single action. Commands are case-sensitive.")
                .font(.caption2)
        }
    }

    // MARK: - Helpers

    private var lastPollText: String {
        guard let date = lastPollDate else { return "Not yet polled" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60  { return "Last polled \(seconds)s ago" }
        if seconds < 3600 { return "Last polled \(seconds / 60)m ago" }
        return "Last polled \(seconds / 3600)h ago"
    }

    private func reload() {
        entries = SharedStorage.shared.loadPushCommandEntries()
        lastPollDate = SharedStorage.shared.ntfyLastPollDate
    }

    private func saveEntries() {
        SharedStorage.shared.savePushCommandEntries(entries)
    }
}

// MARK: - Row View

struct PushCommandRowView: View {
    let entry: PushCommandEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.command.isEmpty ? "(no command set)" : entry.command)
                .font(.headline)
                .foregroundStyle(entry.command.isEmpty ? .secondary : .white)

            if !entry.label.isEmpty {
                Text(entry.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            let payloadSuffix = entry.action.payload.isEmpty ? "" : ": \(entry.action.payload)"
            Text(entry.action.type.displayName + payloadSuffix)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor View

struct PushCommandEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var entry: PushCommandEntry
    let onChanged: () -> Void

    @State private var showActionTypePicker = false

    var body: some View {
        List {
            Section("Trigger") {
                TextField("Command (e.g. kill-bluetooth)", text: $entry.command)
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
                        Text(entry.action.type.displayName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.white)

                if entry.action.type == .urlScheme {
                    TextField("URL Scheme (e.g. myapp://action)", text: $entry.action.payload)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField(
                        entry.action.type == .appIntent ? "Intent Name" : "Shortcut Name",
                        text: $entry.action.payload
                    )
                    .foregroundStyle(.white)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Command")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onChanged()
                    dismiss()
                }
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
                        selectedType = type
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if type == selectedType {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Action Type")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PushCommandView()
        .preferredColorScheme(.dark)
}

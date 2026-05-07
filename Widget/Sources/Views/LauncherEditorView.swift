import SwiftUI
import UniformTypeIdentifiers

// MARK: - Launcher Editor

struct LauncherEditorView: View {
    @EnvironmentObject var viewModel: WidgetViewModel
    @Environment(\.dismiss) private var dismiss

    var config: LauncherConfig
    var isNew: Bool = false

    @State private var draft: LauncherConfig
    @State private var editingItem: LauncherItem?
    @State private var showAddItem = false
    @State private var showImport = false
    @State private var showExportShare = false
    @State private var exportURL: URL?
    @State private var alertMessage = ""
    @State private var showAlert = false

    init(config: LauncherConfig, isNew: Bool = false) {
        self.config = config
        self.isNew = isNew
        _draft = State(initialValue: config)
    }

    var body: some View {
        List {
            // Name
            Section("Name") {
                TextField("Grid name", text: $draft.name)
                    .foregroundStyle(.white)
            }

            // Items
            Section {
                ForEach($draft.items) { $item in
                    Button {
                        editingItem = item
                    } label: {
                        LauncherItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .onMove { from, to in draft.items.move(fromOffsets: from, toOffset: to) }
                .onDelete { offsets in draft.items.remove(atOffsets: offsets) }

                if draft.items.count < LauncherConfig.maxItems {
                    Button {
                        let newItem = LauncherItem()
                        draft.items.append(newItem)
                        editingItem = newItem
                    } label: {
                        Label("Add Item", systemImage: "plus.circle")
                    }
                    .foregroundStyle(.gray)
                }
            } header: {
                HStack {
                    Text("Items (\(draft.items.count)/\(LauncherConfig.maxItems))")
                    Spacer()
                    Button {
                        draft.items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isNew ? "New Launcher Grid" : draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isNew {
                    Button("Cancel") { dismiss() }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        importShortcut()
                    } label: {
                        Label("Import from Shortcut", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        exportShortcut()
                    } label: {
                        Label("Export as Shortcut", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                LauncherItemEditorView(item: bindingFor(item)) {
                    editingItem = nil
                }
            }
        }
        .fileImporter(
            isPresented: $showImport,
            allowedContentTypes: [UTType(filenameExtension: "shortcut") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Launcher Grid", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Helpers

    private func bindingFor(_ item: LauncherItem) -> Binding<LauncherItem> {
        Binding(
            get: { draft.items.first(where: { $0.id == item.id }) ?? item },
            set: { updated in
                if let idx = draft.items.firstIndex(where: { $0.id == updated.id }) {
                    draft.items[idx] = updated
                }
            }
        )
    }

    private func save() {
        if isNew {
            viewModel.addLauncherConfig(draft)
        } else {
            viewModel.updateLauncherConfig(draft)
        }
        dismiss()
    }

    private func importShortcut() {
        showImport = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let items = try ShortcutFileService.importItems(from: data)
            draft.items.append(contentsOf: items.prefix(LauncherConfig.maxItems - draft.items.count))
            alertMessage = "Imported \(items.count) item(s)."
            showAlert = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func exportShortcut() {
        do {
            let data = try ShortcutFileService.exportData(from: draft)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(draft.name).shortcut")
            try data.write(to: url)
            exportURL = url
            showExportShare = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Launcher Item Row

private struct LauncherItemRow: View {
    let item: LauncherItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.isEmpty ? "Unnamed" : item.name)
                    .foregroundStyle(item.name.isEmpty ? Color.secondary : Color.white)

                Text(actionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var actionDescription: String {
        switch item.action.type {
        case .urlScheme: return item.action.payload.isEmpty ? "No URL set" : item.action.payload
        case .shortcut:  return item.action.payload.isEmpty ? "No shortcut set" : "Shortcut: \(item.action.payload)"
        case .appIntent: return item.action.displayName ?? (item.action.payload.isEmpty ? "No app set" : item.action.payload)
        }
    }
}

// MARK: - Launcher Item Editor

struct LauncherItemEditorView: View {
    @Binding var item: LauncherItem
    var onDone: () -> Void

    @State private var showAppPicker = false

    var body: some View {
        List {
            Section("Name") {
                TextField("Item name", text: $item.name)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
            }

            Section {
                Picker("Type", selection: $item.action.type) {
                    ForEach(ActionType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: item.action.type) { _ in
                    item.action.payload = ""
                    item.action.displayName = nil
                }

                switch item.action.type {
                case .urlScheme:
                    TextField("URL (e.g. shortcuts://)", text: $item.action.payload)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                case .shortcut:
                    TextField("Shortcut name", text: $item.action.payload)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()

                case .appIntent:
                    Button {
                        showAppPicker = true
                    } label: {
                        HStack {
                            Text("App Action")
                            Spacer()
                            Text(item.action.displayName ?? (item.action.payload.isEmpty ? "Select…" : item.action.payload))
                                .foregroundStyle(item.action.payload.isEmpty ? .tertiary : .secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.white)
                }
            } header: {
                Text("Action")
            } footer: {
                Text(item.action.type.description)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDone() }
            }
        }
        .sheet(isPresented: $showAppPicker) {
            AppActionPickerView { urlString, displayLabel in
                item.action.payload = urlString
                item.action.displayName = displayLabel
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        LauncherEditorView(config: LauncherConfig(), isNew: true)
            .environmentObject(WidgetViewModel())
    }
    .preferredColorScheme(.dark)
}

import SwiftUI
import UniformTypeIdentifiers

/// Backup and restore view for exporting/importing widget configurations
struct BackupView: View {

    @EnvironmentObject var viewModel: WidgetViewModel
    @State private var showExportPicker = false
    @State private var showImportPicker = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var importingData: Data?

    var body: some View {
        List {
            Section {
                // Export button
                Button {
                    exportConfigurations()
                } label: {
                    Label("Export to Files", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(.white)
                .disabled(isExporting || viewModel.configurations.isEmpty)

                // Import button
                Button {
                    showImportPicker = true
                } label: {
                    Label("Import from Files", systemImage: "square.and.arrow.down")
                }
                .foregroundStyle(.white)
            } header: {
                Text("Backup & Restore")
            } footer: {
                Text("Export your widget configurations to a file for backup or transfer to another device. Import configurations from a previously exported file.")
            }

            if let lastBackup = SharedStorage.shared.lastBackupDate {
                Section {
                    HStack {
                        Text("Last Backup")
                        Spacer()
                        Text(lastBackup, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !viewModel.configurations.isEmpty {
                Section {
                    Text("Total: \(viewModel.configurations.count) widget\(viewModel.configurations.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Backup")
        .fileExporter(
            isPresented: $showExportPicker,
            document: ExportDocument(data: importingData ?? Data()),
            contentType: .json,
            defaultFilename: "WidgetBackup-\(formattedDate())"
        ) { result in
            switch result {
            case .success(let url):
                exportURL = url
                SharedStorage.shared.lastBackupDate = Date()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
            importingData = nil
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func exportConfigurations() {
        isExporting = true
        Task {
            do {
                let data = try viewModel.exportToJSON()
                await MainActor.run {
                    importingData = data
                    showExportPicker = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run {
                isExporting = false
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            Task {
                do {
                    let data = try Data(contentsOf: url)
                    try viewModel.importFromJSON(data)
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Export Document

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static var json: UTType {
        UTType(filenameExtension: "json") ?? .json
    }
}

#Preview {
    NavigationStack {
        BackupView()
            .environmentObject(WidgetViewModel())
    }
    .preferredColorScheme(.dark)
}

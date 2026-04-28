import SwiftUI
import UniformTypeIdentifiers

/// Backup and restore view for exporting/importing widget configurations
struct BackupView: View {

    @EnvironmentObject var viewModel: WidgetViewModel
    @State private var showExportPicker = false
    @State private var showImportPicker = false
    @State private var exportDocument: ExportDocument?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    var body: some View {
        List {
            Section {
                Button {
                    prepareAndExport()
                } label: {
                    Label("Export to Files", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(.white)
                .disabled(viewModel.configurations.isEmpty)

                Button {
                    showImportPicker = true
                } label: {
                    Label("Import from Files", systemImage: "square.and.arrow.down")
                }
                .foregroundStyle(.white)
            } header: {
                Text("Backup & Restore")
            } footer: {
                Text("Export your widget configurations to a JSON file. Import a previously exported file to restore them.")
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
        // fileExporter needs a non-nil document binding; we gate presentation on exportDocument
        .fileExporter(
            isPresented: $showExportPicker,
            document: exportDocument ?? ExportDocument(data: Data()),
            contentType: .json,
            defaultFilename: "WidgetBackup-\(formattedDate())"
        ) { result in
            switch result {
            case .success:
                SharedStorage.shared.lastBackupDate = Date()
                successMessage = "Backup exported successfully."
                showSuccess = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Export

    private func prepareAndExport() {
        do {
            let data = try viewModel.exportToJSON()
            exportDocument = ExportDocument(data: data)
            showExportPicker = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                // Security-scoped resource access required for file importer results
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "Could not access the selected file."
                    showError = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)
                try viewModel.importFromJSON(data)
                successMessage = "Configurations imported successfully."
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
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
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    NavigationStack {
        BackupView()
            .environmentObject(WidgetViewModel())
    }
    .preferredColorScheme(.dark)
}

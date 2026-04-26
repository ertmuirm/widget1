import Foundation
import SwiftUI
import Combine
import WidgetKit

/// Main ViewModel for managing widget configurations
@MainActor
final class WidgetViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var configurations: [WidgetConfig] = []
    @Published var selectedConfiguration: WidgetConfig?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Private Properties
    
    private let storage = SharedStorage.shared
    
    // MARK: - Initialization
    
    init() {
        loadConfigurations()
    }
    
    // MARK: - Configuration Management
    
    /// Load all configurations from storage
    func loadConfigurations() {
        isLoading = true
        do {
            configurations = try storage.loadConfigurations()
        } catch {
            configurations = []
            showError(error)
        }
        isLoading = false
    }
    
    /// Save all configurations to storage
    func saveConfigurations() {
        do {
            try storage.saveConfigurations(configurations)
            // Reload widget timelines so the extension picks up changes
            WidgetCenter.shared.reloadTimelines(ofKind: "BroadcastExtension")
        } catch {
            showError(error)
        }
    }
    
    /// Add a new configuration
    func addConfiguration(_ config: WidgetConfig) {
        configurations.append(config)
        saveConfigurations()
    }
    
    /// Update an existing configuration
    func updateConfiguration(_ config: WidgetConfig) {
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            var updated = config
            updated.updatedAt = Date()
            configurations[index] = updated
            saveConfigurations()
            
            // Update selected if it's the same
            if selectedConfiguration?.id == config.id {
                selectedConfiguration = updated
            }
        }
    }
    
    /// Delete a configuration
    func deleteConfiguration(_ config: WidgetConfig) {
        configurations.removeAll { $0.id == config.id }
        saveConfigurations()
        
        // Clear selected if it was deleted
        if selectedConfiguration?.id == config.id {
            selectedConfiguration = nil
        }
    }
    
    /// Delete configuration at index
    func deleteConfiguration(at offsets: IndexSet) {
        configurations.remove(atOffsets: offsets)
        saveConfigurations()
    }
    
    // MARK: - Item Management
    
    /// Add item to configuration
    func addItem(to config: inout WidgetConfig) {
        guard config.items.count < config.maxItems else { return }
        
        let newItem = WidgetItem()
        config.items.append(newItem)
    }
    
    /// Remove item from configuration
    func removeItem(from config: inout WidgetConfig, at index: Int) {
        guard index >= 0 && index < config.items.count else { return }
        config.items.remove(at: index)
    }
    
    // MARK: - Error Handling
    
    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    // MARK: - Backup
    
    /// Export configurations to JSON data
    func exportToJSON() throws -> Data {
        let exportData = ExportData(configurations: configurations)
        return try JSONEncoder().encode(exportData)
    }
    
    /// Import configurations from JSON data
    func importFromJSON(_ data: Data) throws {
        let exportData = try JSONDecoder().decode(ExportData.self, from: data)
        configurations = exportData.configurations
        saveConfigurations()
    }
}
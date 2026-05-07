import Foundation
import SwiftUI
import Combine
import WidgetKit
import UIKit

/// Main ViewModel for managing widget configurations
@MainActor
final class WidgetViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var configurations: [WidgetConfig] = []
    @Published var launcherConfigs: [LauncherConfig] = []
    @Published var selectedConfiguration: WidgetConfig?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Private Properties

    private let storage = SharedStorage.shared

    // MARK: - Initialization

    init() {
        loadConfigurations()
        loadLauncherConfigs()
        Task { try? storage.createAutoBackup() }
    }

    // MARK: - Configuration Management

    func loadConfigurations() {
        isLoading = true
        do {
            configurations = try storage.loadConfigurations()
        } catch {
            configurations = []
            handleError(error)
        }
        isLoading = false
    }

    // Persist and reload timelines; callers are responsible for haptic feedback
    private func saveConfigurations() {
        do {
            try storage.saveConfigurations(configurations)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            handleError(error)
        }
    }

    func addConfiguration(_ config: WidgetConfig) {
        configurations.append(config)
        saveConfigurations()
        triggerHaptic(.medium)
    }

    func updateConfiguration(_ config: WidgetConfig) {
        guard let index = configurations.firstIndex(where: { $0.id == config.id }) else { return }
        var updated = config
        updated.updatedAt = Date()
        configurations[index] = updated
        saveConfigurations()
        triggerHaptic(.light)

        if selectedConfiguration?.id == config.id {
            selectedConfiguration = updated
        }
    }

    func deleteConfiguration(_ config: WidgetConfig) {
        configurations.removeAll { $0.id == config.id }
        saveConfigurations()
        triggerHaptic(.rigid)

        if selectedConfiguration?.id == config.id {
            selectedConfiguration = nil
        }
    }

    func deleteConfiguration(at offsets: IndexSet) {
        configurations.remove(atOffsets: offsets)
        saveConfigurations()
        triggerHaptic(.rigid)
    }

    func moveConfiguration(from source: IndexSet, to destination: Int) {
        configurations.move(fromOffsets: source, toOffset: destination)
        saveConfigurations()
        triggerHaptic(.light)
    }

    func deleteAllConfigurations() {
        do {
            try storage.deleteAllConfigurations()
            configurations = []
            WidgetCenter.shared.reloadAllTimelines()
            triggerHaptic(.rigid)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Launcher Config Management

    func loadLauncherConfigs() {
        launcherConfigs = (try? storage.loadLauncherConfigs()) ?? []
    }

    private func saveLauncherConfigs() {
        try? storage.saveLauncherConfigs(launcherConfigs)
    }

    func addLauncherConfig(_ config: LauncherConfig) {
        launcherConfigs.append(config)
        saveLauncherConfigs()
        triggerHaptic(.medium)
    }

    func updateLauncherConfig(_ config: LauncherConfig) {
        guard let idx = launcherConfigs.firstIndex(where: { $0.id == config.id }) else { return }
        var updated = config
        updated.updatedAt = Date()
        launcherConfigs[idx] = updated
        saveLauncherConfigs()
        triggerHaptic(.light)
    }

    func deleteLauncherConfig(_ config: LauncherConfig) {
        launcherConfigs.removeAll { $0.id == config.id }
        saveLauncherConfigs()
        triggerHaptic(.rigid)
    }

    func deleteLauncherConfig(at offsets: IndexSet) {
        launcherConfigs.remove(atOffsets: offsets)
        saveLauncherConfigs()
        triggerHaptic(.rigid)
    }

    func moveLauncherConfig(from source: IndexSet, to destination: Int) {
        launcherConfigs.move(fromOffsets: source, toOffset: destination)
        saveLauncherConfigs()
        triggerHaptic(.light)
    }

    // MARK: - Item Management

    func addItem(to config: inout WidgetConfig) {
        guard config.items.count < config.maxItems else { return }
        config.items.append(WidgetItem())
    }

    func removeItem(from config: inout WidgetConfig, at index: Int) {
        guard index >= 0 && index < config.items.count else { return }
        config.items.remove(at: index)
    }

    // MARK: - Backup / Restore

    func exportToJSON() throws -> Data {
        let exportData = ExportData(configurations: configurations)
        return try JSONEncoder().encode(exportData)
    }

    func importFromJSON(_ data: Data) throws {
        // Try ExportData wrapper first, fall back to raw array
        if let exportData = try? JSONDecoder().decode(ExportData.self, from: data) {
            configurations = exportData.configurations
        } else {
            configurations = try JSONDecoder().decode([WidgetConfig].self, from: data)
        }
        saveConfigurations()
    }

    func restoreFromBackup() async -> Bool {
        do {
            let restored = try storage.restoreFromBackup()
            if restored {
                loadConfigurations()
                loadLauncherConfigs()
                WidgetCenter.shared.reloadAllTimelines()
            }
            return restored
        } catch {
            handleError(error)
            return false
        }
    }

    func listAutoBackups() -> [URL] {
        (try? storage.listAutoBackups()) ?? []
    }

    func restoreFromAutoBackup(url: URL) {
        do {
            try storage.restoreFromAutoBackup(url: url)
            loadConfigurations()
            loadLauncherConfigs()
            WidgetCenter.shared.reloadAllTimelines()
            triggerHaptic(.medium)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    // MARK: - Haptic Feedback

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard storage.hapticFeedback else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

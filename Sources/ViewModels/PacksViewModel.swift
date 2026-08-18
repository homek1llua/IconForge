import SwiftUI
import UIKit

@MainActor
final class PacksViewModel: ObservableObject {
    @Published var packs: [IconPack] = []
    @Published var selectedPack: IconPack?
    @Published var isLoading: Bool = false
    @Published var isCreating: Bool = false
    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false
    @Published var showingCreateSheet: Bool = false
    @Published var newPackName: String = ""
    @Published var newPackDescription: String = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let packManager = PackManager()
    private let logger: IconForgeLogger = .shared
    
    func loadPacks() {
        packs = packManager.loadAllPacks()
    }
    
    func createPack() async {
        guard !newPackName.isEmpty else {
            errorMessage = "Pack name cannot be empty."
            return
        }
        isCreating = true
        defer { isCreating = false }
        
        let pack = packManager.createPack(name: newPackName, description: newPackDescription)
        do {
            try packManager.savePack(pack)
            packs.insert(pack, at: 0)
            newPackName = ""
            newPackDescription = ""
            showingCreateSheet = false
            successMessage = "Pack '\(pack.name)' created."
        } catch {
            errorMessage = "Failed to create pack: \(error.localizedDescription)"
        }
    }
    
    func deletePack(_ pack: IconPack) {
        do {
            try packManager.deletePack(pack)
            packs.removeAll { $0.id == pack.id }
            if selectedPack?.id == pack.id { selectedPack = nil }
        } catch {
            errorMessage = "Failed to delete pack: \(error.localizedDescription)"
        }
    }
    
    func duplicatePack(_ pack: IconPack) {
        let newPack = packManager.duplicatePack(pack)
        do {
            try packManager.savePack(newPack)
            packs.insert(newPack, at: 0)
            successMessage = "Duplicated as '\(newPack.name)'"
        } catch {
            errorMessage = "Failed to duplicate pack: \(error.localizedDescription)"
        }
    }
    
    func renamePack(_ pack: IconPack, to newName: String) {
        var updated = pack
        updated.rename(to: newName)
        do {
            try packManager.deletePack(pack)
            try packManager.savePack(updated)
            if let idx = packs.firstIndex(where: { $0.id == pack.id }) {
                packs[idx] = updated
            }
            successMessage = "Renamed to '\(newName)'"
        } catch {
            errorMessage = "Failed to rename pack: \(error.localizedDescription)"
        }
    }
    
    func exportPack(_ pack: IconPack) async {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try await packManager.exportPack(pack, iconDataMap: [:])
            successMessage = "Exported to \(url.lastPathComponent)"
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
        }
    }
    
    func importPack(from url: URL) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let (pack, _) = try await packManager.importPack(from: url)
            try packManager.savePack(pack)
            packs.insert(pack, at: 0)
            successMessage = "Imported '\(pack.name)' with \(pack.iconCount) icons."
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
        }
    }
    
    func applyPack(_ pack: IconPack, apps: [InstalledApp]) async -> (applied: Int, missing: Int, failed: Int) {
        var applied = 0
        var missing = 0
        var failed = 0
        let backend = BackendManager.shared.bestBackend()
        guard let backend else { return (0, 0, pack.iconCount) }
        
        let backupManager = BackupManager()
        let discoveryService = AppDiscoveryService()
        
        for entry in pack.icons {
            guard let targetApp = apps.first(where: { $0.bundleIdentifier == entry.bundleIdentifier }) else {
                missing += 1
                continue
            }
            do {
                _ = try backupManager.createBackup(for: targetApp)
                let image = try await backend.readIcon(for: targetApp)
                try await backend.applyIcon(image, to: targetApp)
                applied += 1
            } catch {
                failed += 1
                logger.error("Failed to apply \(entry.bundleIdentifier): \(error.localizedDescription)")
            }
        }
        
        return (applied, missing, failed)
    }
}

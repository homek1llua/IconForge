import SwiftUI
import UIKit

@MainActor
final class RestoreViewModel: ObservableObject {
    @Published var backups: [IconBackup] = []
    @Published var isLoading: Bool = false
    @Published var isRestoring: Bool = false
    @Published var restoreProgress: Double = 0
    @Published var restoreMessage: String?
    @Published var restoreError: String?
    @Published var showConfirmRestoreAll: Bool = false
    @Published var showConfirmDeleteAll: Bool = false
    @Published var operationLog: BackupOperation?
    
    private let backupManager = BackupManager()
    private let logger: IconForgeLogger = .shared
    
    func loadBackups() {
        backups = backupManager.loadBackups()
    }
    
    func restoreBackup(for bundleIdentifier: String) async {
        isRestoring = true
        restoreError = nil
        restoreMessage = nil
        defer { isRestoring = false }
        
        do {
            let backend = BackendManager.shared.bestBackend()
            guard let backend else {
                throw IconForgeError.unsupportedOperation("No icon backend available")
            }
            
            let backupDir = StorageManager.backupDirectory(for: bundleIdentifier)
            let iconData = try Data(contentsOf: backupDir.appendingPathComponent("original-icon.png"))
            guard let originalImage = UIImage(data: iconData) else {
                throw IconForgeError.iconRestoreFailed(bundleIdentifier, reason: "Failed to decode backup image")
            }
            
            let discoveryService = AppDiscoveryService()
            let allApps = await discoveryService.discoverAllApps()
            guard let app = allApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
                throw IconForgeError.appNotFound(bundleIdentifier)
            }
            
            try await backend.applyIcon(originalImage, to: app)
            restoreMessage = "Successfully restored icon for \(bundleIdentifier)"
            logger.info("Restored icon for \(bundleIdentifier)")
        } catch {
            restoreError = error.localizedDescription
            logger.error("Failed to restore \(bundleIdentifier): \(error.localizedDescription)")
        }
    }
    
    func restoreAll() async {
        isRestoring = true
        restoreError = nil
        restoreMessage = nil
        defer { isRestoring = false }
        
        let discoveryService = AppDiscoveryService()
        let allApps = await discoveryService.discoverAllApps()
        var successCount = 0
        var failCount = 0
        
        restoreProgress = 0
        let total = Double(backups.count)
        
        for backup in backups {
            if let app = allApps.first(where: { $0.bundleIdentifier == backup.bundleIdentifier }) {
                do {
                    let backend = BackendManager.shared.bestBackend()
                    let backupDir = StorageManager.backupDirectory(for: backup.bundleIdentifier)
                    let iconData = try Data(contentsOf: backupDir.appendingPathComponent("original-icon.png"))
                    if let originalImage = UIImage(data: iconData) {
                        try await backend?.applyIcon(originalImage, to: app)
                        successCount += 1
                    } else {
                        failCount += 1
                    }
                } catch {
                    failCount += 1
                }
            } else {
                failCount += 1
            }
            restoreProgress = Double(successCount + failCount) / total
        }
        
        restoreMessage = "Restored \(successCount) icons. \(failCount) failed."
    }
    
    func deleteBackup(for bundleIdentifier: String) {
        do {
            try backupManager.deleteBackup(for: bundleIdentifier)
            backups.removeAll { $0.bundleIdentifier == bundleIdentifier }
        } catch {
            restoreError = error.localizedDescription
        }
    }
    
    func deleteAllBackups() {
        for backup in backups {
            try? backupManager.deleteBackup(for: backup.bundleIdentifier)
        }
        backups.removeAll()
    }
}

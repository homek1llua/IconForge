import Foundation
import UIKit

final class BackupManager: @unchecked Sendable {
    
    private let filesystem: RootFilesystem
    private let paths: JailbreakPaths
    private let logger: IconForgeLogger
    private let storage = StorageManager.self
    
    init(
        filesystem: RootFilesystem = RootFilesystem(),
        paths: JailbreakPaths = .detect(),
        logger: IconForgeLogger = .shared
    ) {
        self.filesystem = filesystem
        self.paths = paths
        self.logger = logger
    }
    
    func createBackup(for app: InstalledApp) throws -> IconBackup {
        let backupDir = storage.backupDirectory(for: app.bundleIdentifier)
        let existingBackups = loadBackups(for: app.bundleIdentifier)
        if !existingBackups.isEmpty {
            logger.warning("Backup already exists for \(app.bundleIdentifier)")
        }
        
        guard let iconPath = app.iconPath,
              filesystem.fileExists(at: iconPath) else {
            throw IconForgeError.iconNotFound(app.bundleIdentifier)
        }
        
        let iconData = try filesystem.readFile(at: iconPath)
        let hash = iconData.sha256Hash
        
        let backupIconURL = backupDir.appendingPathComponent("original-icon.png")
        try filesystem.writeFile(iconData, to: backupIconURL)
        
        let iOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let jbEnvironment = JailbreakDetector.shared.detectEnvironment().environment.rawValue
        
        let backup = IconBackup(
            bundleIdentifier: app.bundleIdentifier,
            appDisplayName: app.displayName,
            originalIconPath: iconPath.path,
            backupIconFilename: "original-icon.png",
            originalFileHash: hash,
            iOSVersion: iOSVersion,
            jailbreakEnvironment: jbEnvironment
        )
        
        let metadata = BackupMetadata(
            backup: backup,
            files: [
                BackedUpFile(
                    relativePath: "original-icon.png",
                    originalFullPath: iconPath.path,
                    filename: iconPath.lastPathComponent,
                    sha256Hash: hash,
                    fileSize: Int64(iconData.count),
                    modificationDate: nil
                )
            ],
            verificationHash: iconData.sha256Hash
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metaData = try encoder.encode(metadata)
        try filesystem.writeFile(metaData, to: backupDir.appendingPathComponent("metadata.json"))
        
        logger.info("Created backup for \(app.bundleIdentifier) (\(app.displayName))")
        return backup
    }
    
    func restoreBackup(for bundleIdentifier: String) throws -> URL {
        let backupDir = storage.backupDirectory(for: bundleIdentifier)
        let metadataURL = backupDir.appendingPathComponent("metadata.json")
        guard filesystem.fileExists(at: metadataURL) else {
            throw IconForgeError.backupNotFound(bundleIdentifier)
        }
        
        let metaData = try filesystem.readFile(at: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(BackupMetadata.self, from: metaData)
        
        let iconData = try filesystem.readFile(at: backupDir.appendingPathComponent("original-icon.png"))
        let currentHash = iconData.sha256Hash
        guard currentHash == metadata.verificationHash else {
            throw IconForgeError.iconRestoreFailed(bundleIdentifier, reason: "Backup integrity check failed")
        }
        
        return backupDir.appendingPathComponent("original-icon.png")
    }
    
    func hasBackup(for bundleIdentifier: String) -> Bool {
        let backupDir = storage.backupDirectory(for: bundleIdentifier)
        return filesystem.fileExists(at: backupDir.appendingPathComponent("metadata.json"))
    }
    
    func loadBackups(for bundleIdentifier: String? = nil) -> [IconBackup] {
        if let bundleIdentifier {
            let backupDir = storage.backupDirectory(for: bundleIdentifier)
            return loadBackupFromDir(backupDir)
        }
        
        let backupsBase = storage.backupsDirectory()
        guard let dirs = try? filesystem.contentsOfDirectory(at: backupsBase) else { return [] }
        
        var allBackups: [IconBackup] = []
        for dir in dirs where dir.isDirectory {
            allBackups.append(contentsOf: loadBackupFromDir(dir))
        }
        return allBackups.sorted { $0.createdAt > $1.createdAt }
    }
    
    func deleteBackup(for bundleIdentifier: String) throws {
        let backupDir = storage.backupDirectory(for: bundleIdentifier)
        if filesystem.fileExists(at: backupDir) {
            try filesystem.removeItem(at: backupDir)
            logger.info("Deleted backup for \(bundleIdentifier)")
        }
    }
    
    func backupIconImage(for bundleIdentifier: String) -> UIImage? {
        let backupDir = storage.backupDirectory(for: bundleIdentifier)
        let iconURL = backupDir.appendingPathComponent("original-icon.png")
        guard let data = try? Data(contentsOf: iconURL) else { return nil }
        return UIImage(data: data)
    }
    
    func backupCount() -> Int {
        let backupsBase = storage.backupsDirectory()
        guard let dirs = try? filesystem.contentsOfDirectory(at: backupsBase) else { return 0 }
        return dirs.filter { $0.isDirectory }.count
    }
    
    private func loadBackupFromDir(_ dir: URL) -> [IconBackup] {
        let metadataURL = dir.appendingPathComponent("metadata.json")
        guard filesystem.fileExists(at: metadataURL),
              let data = try? filesystem.readFile(at: metadataURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(BackupMetadata.self, from: data)).map { [$0.backup] } ?? []
    }
}

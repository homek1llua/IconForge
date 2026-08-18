import Foundation
import UIKit

final class IconBackendIOS15: IconBackend, @unchecked Sendable {
    
    let name = "iOS 15 Bundle Replace"
    var isAvailable: Bool = true
    
    private let filesystem: RootFilesystem
    private let paths: JailbreakPaths
    private let iconCacheManager: IconCacheManager
    private let launchServices: LaunchServicesManager
    private let logger: IconForgeLogger
    
    init(
        filesystem: RootFilesystem,
        paths: JailbreakPaths,
        iconCacheManager: IconCacheManager,
        launchServices: LaunchServicesManager,
        logger: IconForgeLogger
    ) {
        self.filesystem = filesystem
        self.paths = paths
        self.iconCacheManager = iconCacheManager
        self.launchServices = launchServices
        self.logger = logger
        self.isAvailable = Self.checkAvailability(paths: paths, filesystem: filesystem)
    }
    
    private static func checkAvailability(paths: JailbreakPaths, filesystem: RootFilesystem) -> Bool {
        filesystem.fileExists(at: paths.varMobile) ||
        filesystem.fileExists(at: URL(fileURLWithPath: "/var/mobile"))
    }
    
    func readIcon(for app: InstalledApp) async throws -> UIImage {
        if let iconPath = app.iconPath, filesystem.fileExists(at: iconPath) {
            let data = try filesystem.readFile(at: iconPath)
            guard let image = UIImage(data: data) else {
                throw IconForgeError.iconNotFound(app.bundleIdentifier)
            }
            return image
        }
        let candidates = app.bundlePath.appendingPathComponent("AppIcon-120.png")
        if filesystem.fileExists(at: candidates) {
            let data = try filesystem.readFile(at: candidates)
            if let image = UIImage(data: data) { return image }
        }
        let generic = app.bundlePath.appendingPathComponent("AppIcon.png")
        if filesystem.fileExists(at: generic) {
            let data = try filesystem.readFile(at: generic)
            if let image = UIImage(data: data) { return image }
        }
        throw IconForgeError.iconNotFound(app.bundleIdentifier)
    }
    
    func applyIcon(_ image: UIImage, to app: InstalledApp) async throws {
        logger.info("iOS15 Backend: Applying icon to \(app.bundleIdentifier)")
        guard let iconData = image.pngData() else {
            throw IconForgeError.imageProcessingFailed("Failed to encode icon as PNG")
        }
        let targets = findIconTargets(for: app)
        for target in targets {
            try filesystem.writeFile(iconData, to: target)
        }
        await refreshIcon(for: app)
        logger.info("iOS15 Backend: Successfully applied icon to \(app.bundleIdentifier)")
    }
    
    func restoreOriginalIcon(for app: InstalledApp) async throws {
        logger.info("iOS15 Backend: Restoring icon for \(app.bundleIdentifier)")
        let backupManager = BackupManager(filesystem: filesystem, paths: paths, logger: logger)
        guard backupManager.hasBackup(for: app.bundleIdentifier) else {
            throw IconForgeError.backupNotFound(app.bundleIdentifier)
        }
        let backupIconURL = try backupManager.restoreBackup(for: app.bundleIdentifier)
        let iconData = try filesystem.readFile(at: backupIconURL)
        let targets = findIconTargets(for: app)
        for target in targets {
            try filesystem.writeFile(iconData, to: target)
        }
        await refreshIcon(for: app)
    }
    
    func refreshIcon(for app: InstalledApp) async {
        iconCacheManager.refreshIcon(for: app.bundleIdentifier)
    }
    
    func refreshAllIcons() async {
        iconCacheManager.refreshAllIcons()
    }
    
    private func findIconTargets(for app: InstalledApp) -> [URL] {
        var targets: [URL] = []
        let names = [
            "AppIcon-120.png", "AppIcon-180.png",
            "AppIcon60x60@2x.png", "AppIcon60x60@3x.png",
            "AppIcon.png"
        ]
        for name in names {
            let path = app.bundlePath.appendingPathComponent(name)
            if filesystem.fileExists(at: path) {
                targets.append(path)
            }
        }
        if targets.isEmpty {
            targets.append(app.bundlePath.appendingPathComponent("AppIcon.png"))
        }
        return targets
    }
}

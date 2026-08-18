import Foundation
import UIKit

final class IconBackendIOS14: IconBackend, @unchecked Sendable {
    
    let name = "iOS 14 Bundle Replace"
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
        let candidatePaths = [
            app.bundlePath.appendingPathComponent("AppIcon60x60@2x.png"),
            app.bundlePath.appendingPathComponent("AppIcon60x60@3x.png"),
            app.bundlePath.appendingPathComponent("AppIcon.png"),
            app.bundlePath.appendingPathComponent("Icon.png"),
            app.bundlePath.appendingPathComponent("icon.png"),
        ]
        for path in candidatePaths {
            if filesystem.fileExists(at: path) {
                let data = try filesystem.readFile(at: path)
                if let image = UIImage(data: data) { return image }
            }
        }
        throw IconForgeError.iconNotFound(app.bundleIdentifier)
    }
    
    func applyIcon(_ image: UIImage, to app: InstalledApp) async throws {
        logger.info("iOS14 Backend: Applying icon to \(app.bundleIdentifier)")
        
        guard let iconTargets = findIconTargets(for: app) else {
            throw IconForgeError.iconApplicationFailed(app.bundleIdentifier, reason: "No icon targets found")
        }
        
        guard let iconData = image.pngData() else {
            throw IconForgeError.imageProcessingFailed("Failed to encode icon as PNG")
        }
        
        for target in iconTargets {
            try filesystem.writeFile(iconData, to: target)
            logger.debug("Wrote icon to \(target.path)")
        }
        
        await refreshIcon(for: app)
        logger.info("iOS14 Backend: Successfully applied icon to \(app.bundleIdentifier)")
    }
    
    func restoreOriginalIcon(for app: InstalledApp) async throws {
        logger.info("iOS14 Backend: Restoring icon for \(app.bundleIdentifier)")
        let backupManager = BackupManager(filesystem: filesystem, paths: paths, logger: logger)
        
        guard backupManager.hasBackup(for: app.bundleIdentifier) else {
            throw IconForgeError.backupNotFound(app.bundleIdentifier)
        }
        
        let backupIconURL = try backupManager.restoreBackup(for: app.bundleIdentifier)
        let iconData = try filesystem.readFile(at: backupIconURL)
        
        guard let iconTargets = findIconTargets(for: app) else {
            throw IconForgeError.iconRestoreFailed(app.bundleIdentifier, reason: "No icon targets found")
        }
        
        for target in iconTargets {
            try filesystem.writeFile(iconData, to: target)
        }
        
        await refreshIcon(for: app)
        logger.info("iOS14 Backend: Successfully restored icon for \(app.bundleIdentifier)")
    }
    
    func refreshIcon(for app: InstalledApp) async {
        iconCacheManager.refreshIcon(for: app.bundleIdentifier)
    }
    
    func refreshAllIcons() async {
        iconCacheManager.refreshAllIcons()
    }
    
    private func findIconTargets(for app: InstalledApp) -> [URL]? {
        let bundle = app.bundlePath
        var targets: [URL] = []
        
        let primaryIcons = [
            "AppIcon60x60@2x.png",
            "AppIcon60x60@3x.png",
            "AppIcon-120.png",
            "AppIcon-180.png",
            "AppIcon.png",
        ]
        for name in primaryIcons {
            let path = bundle.appendingPathComponent(name)
            if filesystem.fileExists(at: path) {
                targets.append(path)
            }
        }
        
        if targets.isEmpty {
            let fallback = bundle.appendingPathComponent("AppIcon.png")
            targets.append(fallback)
        }
        
        return targets.isEmpty ? nil : targets
    }
}

import Foundation
import UIKit

final class IconBackendIOS15: IconBackend, @unchecked Sendable {

    let name = "iOS 15 Privileged Bundle Replace"
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
            if let image = UIImage(data: data) { return image }
        }

        let targets = IconResourceResolver.resolveIconTargets(for: app)
        for target in targets {
            if filesystem.fileExists(at: target) {
                let data = try filesystem.readFile(at: target)
                if let image = UIImage(data: data) { return image }
            }
        }

        throw IconForgeError.iconNotFound(app.bundleIdentifier)
    }

    func applyIcon(_ image: UIImage, to app: InstalledApp) async throws {
        logger.info("iOS15 Backend: Applying icon to \(app.bundleIdentifier)")

        guard let iconData = image.pngData() else {
            throw IconForgeError.imageProcessingFailed("Failed to encode icon as PNG")
        }

        let targets = IconResourceResolver.resolveIconTargets(for: app)
        guard !targets.isEmpty else {
            throw IconForgeError.iconApplicationFailed(
                app.bundleIdentifier,
                reason: "No icon resources found in application bundle"
            )
        }

        var writeErrors: [String] = []
        for target in targets {
            let result = try PrivilegedHelper.writeFile(
                data: iconData,
                to: target,
                backupOriginal: true,
                logger: logger
            )
            if result.success {
                logger.info("Wrote icon to \(target.path)")
            } else {
                writeErrors.append("\(target.lastPathComponent): \(result.errorMessage ?? "unknown")")
            }
        }

        guard writeErrors.isEmpty else {
            throw IconForgeError.iconApplicationFailed(
                app.bundleIdentifier,
                reason: "Failed to write \(writeErrors.count) icon(s): \(writeErrors.joined(separator: "; "))"
            )
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

        let targets = IconResourceResolver.resolveIconTargets(for: app)
        for target in targets {
            let result = try PrivilegedHelper.writeFile(
                data: iconData,
                to: target,
                backupOriginal: false,
                logger: logger
            )
            guard result.success else {
                throw IconForgeError.iconRestoreFailed(
                    app.bundleIdentifier,
                    reason: "Failed to write \(target.lastPathComponent): \(result.errorMessage ?? "unknown")"
                )
            }
        }

        await refreshIcon(for: app)
        logger.info("iOS15 Backend: Successfully restored icon for \(app.bundleIdentifier)")
    }

    func refreshIcon(for app: InstalledApp) async {
        iconCacheManager.refreshIcon(for: app.bundleIdentifier)
    }

    func refreshAllIcons() async {
        iconCacheManager.refreshAllIcons()
    }
}

import Foundation
import UIKit

final class IconBackendIOS18: IconBackend, @unchecked Sendable {

    let name = "iOS 18 Privileged + Full Cache Invalidation"
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

        if let cached = findCachedIcon(for: app) {
            let data = try filesystem.readFile(at: cached)
            if let image = UIImage(data: data) { return image }
        }

        throw IconForgeError.iconNotFound(app.bundleIdentifier)
    }

    func applyIcon(_ image: UIImage, to app: InstalledApp) async throws {
        logger.info("iOS18 Backend: Applying icon to \(app.bundleIdentifier)")

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

        updateAllCaches(for: app, data: iconData)
        clearAllIconCaches(for: app)
        await refreshIcon(for: app)
        logger.info("iOS18 Backend: Successfully applied icon to \(app.bundleIdentifier)")
    }

    func restoreOriginalIcon(for app: InstalledApp) async throws {
        logger.info("iOS18 Backend: Restoring icon for \(app.bundleIdentifier)")
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

        clearAllIconCaches(for: app)
        await refreshIcon(for: app)
    }

    func refreshIcon(for app: InstalledApp) async {
        iconCacheManager.refreshIcon(for: app.bundleIdentifier)
    }

    func refreshAllIcons() async {
        iconCacheManager.rebuildIconDatabase()
    }

    private func findCachedIcon(for app: InstalledApp) -> URL? {
        let cacheDirs = [
            paths.caches.appendingPathComponent("com.apple.IconsCache"),
            URL(fileURLWithPath: "/var/mobile/Library/Caches/com.apple.IconsCache"),
            URL(fileURLWithPath: "/var/mobile/Library/Caches/com.apple.springboard"),
        ]
        for dir in cacheDirs {
            let cached = dir.appendingPathComponent("\(app.bundleIdentifier).png")
            if filesystem.fileExists(at: cached) { return cached }
        }
        return nil
    }

    private func updateAllCaches(for app: InstalledApp, data: Data) {
        let cacheDirs = [
            paths.caches.appendingPathComponent("com.apple.IconsCache"),
            URL(fileURLWithPath: "/var/mobile/Library/Caches/com.apple.IconsCache"),
        ]
        for dir in cacheDirs {
            if filesystem.fileExists(at: dir) {
                let cacheFile = dir.appendingPathComponent("\(app.bundleIdentifier).png")
                try? PrivilegedHelper.writeFile(data: data, to: cacheFile, backupOriginal: false, logger: logger)
            }
        }
    }

    private func clearAllIconCaches(for app: InstalledApp) {
        let cacheDirs = [
            "/var/mobile/Library/Caches/com.apple.IconsCache",
            "/var/mobile/Library/Caches/com.apple.springboard",
            "/Library/Caches/com.apple.IconsCache",
        ]
        for dir in cacheDirs {
            guard let enumerator = FileManager.default.enumerator(atPath: dir) else { continue }
            while let file = enumerator.nextObject() as? String {
                if file.hasPrefix(app.bundleIdentifier) {
                    PrivilegedHelper.removeFile(at: "\(dir)/\(file)", logger: logger)
                }
            }
        }
    }
}

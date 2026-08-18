import Foundation

final class IconCacheManager: @unchecked Sendable {

    private let paths: JailbreakPaths
    private let filesystem: RootFilesystem
    private let launchServices: LaunchServicesManager

    private static let iconCachePaths: [String] = [
        "/var/mobile/Library/Caches/com.apple.IconsCache",
        "/var/mobile/Library/Caches/com.apple.springboard",
        "/Library/Caches/com.apple.IconsCache",
        "/var/mobile/Library/SpringBoard/IconCache",
        "/private/var/mobile/Library/Caches/com.apple.IconsCache",
    ]

    init(
        paths: JailbreakPaths = .detect(),
        filesystem: RootFilesystem = RootFilesystem(),
        launchServices: LaunchServicesManager = LaunchServicesManager()
    ) {
        self.paths = paths
        self.filesystem = filesystem
        self.launchServices = launchServices
    }

    func refreshAllIcons() {
        launchServices.refreshLaunchServices()
    }

    func refreshIcon(for bundleIdentifier: String) {
        launchServices.refreshIconForBundle(bundleIdentifier)
    }

    func clearIconCaches() {
        for cachePath in Self.iconCachePaths {
            let url = URL(fileURLWithPath: cachePath)
            if filesystem.fileExists(at: url) {
                try? filesystem.removeItem(at: url)
            }
        }
    }

    func rebuildIconDatabase() {
        clearIconCaches()
        refreshAllIcons()
    }

    func availableCacheDirectories() -> [URL] {
        Self.iconCachePaths
            .map { URL(fileURLWithPath: $0) }
            .filter { filesystem.fileExists(at: $0) }
    }

    func cacheSize() -> Int64 {
        var total: Int64 = 0
        for dir in availableCacheDirectories() {
            total += directorySize(at: dir)
        }
        return total
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
}

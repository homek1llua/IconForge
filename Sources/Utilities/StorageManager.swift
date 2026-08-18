import Foundation

struct StorageManager {
    
    private static let baseDirectoryName = "IconForge"
    
    static func baseDirectory() -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base = paths[0].appendingPathComponent(baseDirectoryName)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    
    static func packsDirectory() -> URL {
        let dir = baseDirectory().appendingPathComponent("Packs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func backupsDirectory() -> URL {
        let dir = baseDirectory().appendingPathComponent("Backups")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func cacheDirectory() -> URL {
        let dir = baseDirectory().appendingPathComponent("Cache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func logsDirectory() -> URL {
        let dir = baseDirectory().appendingPathComponent("Logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func tempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("iconforge")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func backupDirectory(for bundleIdentifier: String) -> URL {
        let dir = backupsDirectory().appendingPathComponent(PathSanitizer.sanitizeFilename(bundleIdentifier))
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func cachedIconURL(for bundleIdentifier: String) -> URL {
        cacheDirectory().appendingPathComponent("\(PathSanitizer.sanitizeFilename(bundleIdentifier))-icon.png")
    }
    
    static func packFileURL(for packName: String) -> URL {
        packsDirectory().appendingPathComponent("\(PathSanitizer.sanitizeFilename(packName)).iconpack")
    }
    
    static func operationLogsDirectory() -> URL {
        let dir = baseDirectory().appendingPathComponent("OperationLogs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func totalStorageUsed() -> Int64 {
        directorySize(at: baseDirectory())
    }
    
    static func backupStorageUsed() -> Int64 {
        directorySize(at: backupsDirectory())
    }
    
    static func cacheStorageUsed() -> Int64 {
        directorySize(at: cacheDirectory())
    }
    
    static func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory())
        _ = cacheDirectory()
    }
    
    static func clearLogs() {
        try? FileManager.default.removeItem(at: logsDirectory())
        _ = logsDirectory()
    }
    
    private static func directorySize(at url: URL) -> Int64 {
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

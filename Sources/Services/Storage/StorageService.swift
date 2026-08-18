import Foundation

final class StorageService: @unchecked Sendable {
    
    static let shared = StorageService()
    
    private init() {}
    
    func storeTemporaryImage(_ data: Data, withIdentifier identifier: String) -> URL? {
        let url = StorageManager.tempDirectory().appendingPathComponent("\(identifier).png")
        try? data.write(to: url)
        return url
    }
    
    func loadCachedImage(withIdentifier identifier: String) -> Data? {
        let url = StorageManager.cachedIconURL(for: identifier)
        return try? Data(contentsOf: url)
    }
    
    func cacheImage(_ data: Data, withIdentifier identifier: String) {
        let url = StorageManager.cachedIconURL(for: identifier)
        try? data.write(to: url)
    }
    
    func clearAllTemporaryFiles() {
        let tempDir = StorageManager.tempDirectory()
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func storageInfo() -> StorageInfo {
        StorageInfo(
            totalUsed: StorageManager.totalStorageUsed(),
            backupUsed: StorageManager.backupStorageUsed(),
            cacheUsed: StorageManager.cacheStorageUsed(),
            packsCount: StorageManager.packsDirectory().countFiles(),
            backupsCount: StorageManager.backupsDirectory().countFiles()
        )
    }
}

struct StorageInfo: Sendable {
    let totalUsed: Int64
    let backupUsed: Int64
    let cacheUsed: Int64
    let packsCount: Int
    let backupsCount: Int
    
    var formattedTotal: String { ByteCountFormatter.string(fromByteCount: totalUsed, countStyle: .file) }
    var formattedBackups: String { ByteCountFormatter.string(fromByteCount: backupUsed, countStyle: .file) }
    var formattedCache: String { ByteCountFormatter.string(fromByteCount: cacheUsed, countStyle: .file) }
}

extension URL {
    func countFiles() -> Int {
        (try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil).count) ?? 0
    }
}

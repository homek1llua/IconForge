import Foundation

struct OperationGuard {
    
    private static var activeOperations: Set<UUID> = []
    private static let lock = NSLock()
    
    static func beginOperation() -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        let id = UUID()
        guard activeOperations.count < 3 else { return nil }
        activeOperations.insert(id)
        return id
    }
    
    static func endOperation(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        activeOperations.remove(id)
    }
    
    static var isIdle: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeOperations.isEmpty
    }
    
    static func validateApplyRequest(
        bundleIdentifier: String,
        filesystem: RootFilesystem,
        paths: JailbreakPaths
    ) -> Result<Void, IconForgeError> {
        guard let sanitized = PathSanitizer.sanitizeBundleIdentifier(bundleIdentifier) else {
            return .failure(.invalidBundleIdentifier(bundleIdentifier))
        }
        guard filesystem.fileExists(at: paths.varMobile) else {
            return .failure(.filesystemNotAccessible)
        }
        return .success(())
    }
    
    static func validateRestoreRequest(
        bundleIdentifier: String,
        backupExists: Bool
    ) -> Result<Void, IconForgeError> {
        guard let _ = PathSanitizer.sanitizeBundleIdentifier(bundleIdentifier) else {
            return .failure(.invalidBundleIdentifier(bundleIdentifier))
        }
        guard backupExists else {
            return .failure(.backupNotFound(bundleIdentifier))
        }
        return .success(())
    }
}

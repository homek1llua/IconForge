import Foundation

enum IconForgeError: Error, LocalizedError, Sendable {
    case jailbreakNotDetected
    case rootAccessDenied
    case filesystemNotAccessible
    case appNotFound(String)
    case invalidBundleIdentifier(String)
    case iconNotFound(String)
    case backupNotFound(String)
    case backupAlreadyExists(String)
    case iconApplicationFailed(String, reason: String)
    case iconRestoreFailed(String, reason: String)
    case cacheRefreshFailed(String)
    case respringFailed(String)
    case imageProcessingFailed(String)
    case packImportFailed(String)
    case packExportFailed(String)
    case packManifestInvalid(String)
    case archiveCorrupted(String)
    case operationCancelled
    case operationFailed(String)
    case insufficientStorage
    case permissionDenied(String)
    case unsupportedIOSVersion(String)
    case unsupportedOperation(String)
    case internalError(String)
    
    var errorDescription: String? {
        switch self {
        case .jailbreakNotDetected: return "Jailbreak not detected. This app requires a jailbroken device."
        case .rootAccessDenied: return "Root filesystem access is not available."
        case .filesystemNotAccessible: return "Unable to access the required filesystem."
        case .appNotFound(let id): return "Application not found: \(id)"
        case .invalidBundleIdentifier(let id): return "Invalid bundle identifier: \(id)"
        case .iconNotFound(let id): return "Icon not found for: \(id)"
        case .backupNotFound(let id): return "No backup found for: \(id)"
        case .backupAlreadyExists(let id): return "A backup already exists for: \(id)"
        case .iconApplicationFailed(let id, let reason): return "Failed to apply icon to \(id): \(reason)"
        case .iconRestoreFailed(let id, let reason): return "Failed to restore icon for \(id): \(reason)"
        case .cacheRefreshFailed(let reason): return "Failed to refresh icon cache: \(reason)"
        case .respringFailed(let reason): return "Respring failed: \(reason)"
        case .imageProcessingFailed(let reason): return "Image processing failed: \(reason)"
        case .packImportFailed(let reason): return "Failed to import icon pack: \(reason)"
        case .packExportFailed(let reason): return "Failed to export icon pack: \(reason)"
        case .packManifestInvalid(let reason): return "Invalid icon pack manifest: \(reason)"
        case .archiveCorrupted(let reason): return "Archive is corrupted: \(reason)"
        case .operationCancelled: return "Operation was cancelled."
        case .operationFailed(let reason): return "Operation failed: \(reason)"
        case .insufficientStorage: return "Insufficient storage space."
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        case .unsupportedIOSVersion(let ver): return "Unsupported iOS version: \(ver)"
        case .unsupportedOperation(let msg): return "This operation is not available: \(msg)"
        case .internalError(let msg): return "Internal error: \(msg)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .jailbreakNotDetected: return "Install a compatible jailbreak and try again."
        case .rootAccessDenied: return "Ensure your jailbreak provides root filesystem access."
        case .cacheRefreshFailed: return "Try running uicache manually from a terminal."
        case .respringFailed: return "Try respringing manually from your jailbreak manager."
        case .unsupportedIOSVersion: return "Check for app updates that may support your iOS version."
        default: return nil
        }
    }
}

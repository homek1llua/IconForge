import Foundation

struct DiagnosticsReport: Sendable {
    var jailbreakDetected: Bool = false
    var environment: String = "Unknown"
    var iosVersion: String = "Unknown"
    var architecture: String = "Unknown"
    var rootAccess: Bool = false
    var launchServicesAccess: Bool = false
    var iconBackend: String = "None"
    var iconCacheAccess: Bool = false
    var respringCapability: Bool = false
    var installedAppsCount: Int = 0
    var customizedAppsCount: Int = 0
    var backupCount: Int = 0
    var storageUsed: Int64 = 0
    var availableUtilities: [String: Bool] = [:]
    var errors: [String] = []
    var warnings: [String] = []
    var timestamp: Date = Date()

    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file)
    }

    var isHealthy: Bool {
        jailbreakDetected && rootAccess && iconBackend != "None" && errors.isEmpty
    }
}

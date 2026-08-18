import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var jailbreakStatus: JailbreakStatus?
    @Published var diagnosticsReport: DiagnosticsReport?
    @Published var isRunningDiagnostics: Bool = false
    @Published var storageInfo: StorageInfo?
    @Published var appearance: AppAppearance = .system
    @Published var hapticsEnabled: Bool = true
    @Published var animationsEnabled: Bool = true
    @Published var autoRefreshCache: Bool = true
    @Published var autoRespring: Bool = false
    @Published var backupBeforeModifying: Bool = true
    @Published var preserveOriginalIcon: Bool = true
    
    private let logger: IconForgeLogger = .shared
    private let iconCacheManager = IconCacheManager()
    
    var jailbreakEnvironment: String {
        jailbreakStatus?.environment.rawValue ?? "Unknown"
    }
    
    var isRootless: Bool {
        jailbreakStatus?.environment == .jailbrokenRootless
    }
    
    var rootPath: String {
        jailbreakStatus?.rootPath.path ?? "Unknown"
    }
    
    var backendName: String {
        BackendManager.shared.backendName()
    }
    
    func detectJailbreak() {
        jailbreakStatus = JailbreakDetector.shared.detectEnvironment()
    }
    
    func runDiagnostics() async {
        isRunningDiagnostics = true
        defer { isRunningDiagnostics = false }
        
        var report = DiagnosticsReport()
        let status = JailbreakDetector.shared.detectEnvironment()
        
        report.jailbreakDetected = status.environment != .jailed
        report.environment = status.environment.rawValue
        report.iosVersion = ProcessInfo.processInfo.operatingSystemVersionString
        report.architecture = detectArchitecture()
        report.rootAccess = status.rootAccessAvailable
        report.launchServicesAccess = status.supports(.launchServicesAccess)
        report.iconBackend = BackendManager.shared.backendName()
        report.iconCacheAccess = status.supports(.cacheRefresh)
        report.respringCapability = status.supports(.respring)
        report.availableUtilities = status.availableUtilities
        report.errors = status.errorMessages
        report.timestamp = Date()
        
        let discoveryService = AppDiscoveryService()
        let apps = await discoveryService.discoverAllApps()
        report.installedAppsCount = apps.count
        report.customizedAppsCount = apps.filter { $0.isCustomized }.count
        
        let backupManager = BackupManager()
        report.backupCount = backupManager.backupCount()
        report.storageUsed = StorageManager.totalStorageUsed()
        
        diagnosticsReport = report
    }
    
    func loadStorageInfo() {
        storageInfo = StorageService.shared.storageInfo()
    }
    
    func clearCache() {
        StorageManager.clearCache()
        iconCacheManager.clearIconCaches()
        loadStorageInfo()
    }
    
    func clearLogs() {
        StorageManager.clearLogs()
        logger.clearEntries()
    }
    
    func rebuildIconDatabase() {
        iconCacheManager.rebuildIconDatabase()
    }
    
    func exportDiagnosticLogs() -> String {
        logger.exportLogs()
    }
    
    private func detectArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(arm64e)
        return "arm64e"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

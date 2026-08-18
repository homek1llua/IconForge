import SwiftUI
import UIKit

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var isJailbroken: Bool = false
    @Published var jailbreakStatus: JailbreakStatus?
    @Published var totalApps: Int = 0
    @Published var customizedCount: Int = 0
    @Published var packCount: Int = 0
    @Published var backupCount: Int = 0
    @Published var recentActivity: [ActivityItem] = []
    @Published var isLoading: Bool = false
    
    private let discoveryService = AppDiscoveryService()
    private let backupManager = BackupManager()
    private let packManager = PackManager()
    
    struct ActivityItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let date: Date
    }
    
    func loadDashboard() async {
        isLoading = true
        defer { isLoading = false }
        
        let status = JailbreakDetector.shared.detectEnvironment()
        jailbreakStatus = status
        isJailbroken = status.environment != .jailed
        
        guard isJailbroken else { return }
        
        let apps = await discoveryService.discoverAllApps()
        totalApps = apps.count
        customizedCount = apps.filter { $0.isCustomized }.count
        packCount = packManager.loadAllPacks().count
        backupCount = backupManager.backupCount()
        
        buildRecentActivity(apps: apps)
    }
    
    func refreshDashboard() async {
        await loadDashboard()
    }
    
    private func buildRecentActivity(apps: [InstalledApp]) {
        var items: [ActivityItem] = []
        let backups = backupManager.loadBackups()
        for backup in backups.prefix(10) {
            items.append(ActivityItem(
                title: "Backed up \(backup.appDisplayName)",
                subtitle: backup.createdAt.displayString,
                icon: "arrow.down.circle",
                date: backup.createdAt
            ))
        }
        recentActivity = Array(items.sorted { $0.date > $1.date }.prefix(10))
    }
}

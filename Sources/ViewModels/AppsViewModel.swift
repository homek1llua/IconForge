import SwiftUI
import UIKit

enum AppFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case customized = "Customized"
    case original = "Original"
    case userApps = "User Apps"
    case systemApps = "System Apps"
    
    var id: String { rawValue }
}

enum AppSortOption: String, CaseIterable, Identifiable {
    case alphabetical = "Alphabetical"
    case recentlyCustomized = "Recently Customized"
    case bundleIdentifier = "Bundle ID"
    case customizedFirst = "Customized First"
    
    var id: String { rawValue }
}

@MainActor
final class AppsViewModel: ObservableObject {
    @Published var allApps: [InstalledApp] = []
    @Published var filteredApps: [InstalledApp] = []
    @Published var searchText: String = "" { didSet { applyFilters() } }
    @Published var selectedFilter: AppFilter = .all { didSet { applyFilters() } }
    @Published var sortOption: AppSortOption = .alphabetical { didSet { applyFilters() } }
    @Published var isLoading: Bool = false
    @Published var selectedApps: Set<String> = []
    @Published var iconCache: [String: UIImage] = [:]
    
    private let discoveryService = AppDiscoveryService()
    private let backupManager = BackupManager()
    private let logger: IconForgeLogger = .shared
    
    var selectedCount: Int { selectedApps.count }
    var hasSelection: Bool { !selectedApps.isEmpty }
    
    func loadApps() async {
        isLoading = true
        defer { isLoading = false }
        allApps = await discoveryService.discoverAllApps()
        loadCustomizationStatus()
        loadIconThumbnails()
        applyFilters()
    }
    
    func refreshApps() async {
        await loadApps()
    }
    
    func toggleSelection(for bundleIdentifier: String) {
        if selectedApps.contains(bundleIdentifier) {
            selectedApps.remove(bundleIdentifier)
        } else {
            selectedApps.insert(bundleIdentifier)
        }
    }
    
    func selectAll() {
        selectedApps = Set(filteredApps.map(\.bundleIdentifier))
    }
    
    func deselectAll() {
        selectedApps.removeAll()
    }
    
    func loadIcon(for app: InstalledApp) -> UIImage? {
        if let cached = iconCache[app.bundleIdentifier] {
            return cached
        }
        let image = discoveryService.loadIcon(for: app)
        if let image {
            iconCache[app.bundleIdentifier] = image
        }
        return image
    }
    
    func isCustomized(_ app: InstalledApp) -> Bool {
        backupManager.hasBackup(for: app.bundleIdentifier)
    }
    
    private func loadCustomizationStatus() {
        let backups = backupManager.loadBackups()
        let customizedSet = Set(backups.map(\.bundleIdentifier))
        allApps = allApps.map { app in
            return InstalledApp(
                id: app.id,
                bundleIdentifier: app.bundleIdentifier,
                displayName: app.displayName,
                bundlePath: app.bundlePath,
                iconPath: app.iconPath,
                isSystemApp: app.isSystemApp,
                isUserApp: app.isUserApp,
                version: app.version,
                shortVersion: app.shortVersion,
                containerURL: app.containerURL,
                groupContainerURLs: app.groupContainerURLs,
                isCustomized: customizedSet.contains(app.bundleIdentifier),
                originalIconBackupPath: app.originalIconBackupPath
            )
        }
    }
    
    private func loadIconThumbnails() {
        for app in allApps.prefix(50) {
            if iconCache[app.bundleIdentifier] == nil {
                let image = discoveryService.loadIcon(for: app)
                if let image {
                    iconCache[app.bundleIdentifier] = image
                }
            }
        }
    }
    
    private func applyFilters() {
        var result = allApps
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.bundleIdentifier.lowercased().contains(query)
            }
        }
        
        switch selectedFilter {
        case .all: break
        case .customized: result = result.filter { $0.isCustomized }
        case .original: result = result.filter { !$0.isCustomized }
        case .userApps: result = result.filter { $0.isUserApp }
        case .systemApps: result = result.filter { $0.isSystemApp }
        }
        
        switch sortOption {
        case .alphabetical: result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .recentlyCustomized: result.sort { $0.isCustomized && !$1.isCustomized }
        case .bundleIdentifier: result.sort { $0.bundleIdentifier < $1.bundleIdentifier }
        case .customizedFirst: result.sort { ($0.isCustomized ? 0 : 1) < ($1.isCustomized ? 0 : 1) }
        }
        
        filteredApps = result
    }
}

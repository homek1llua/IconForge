import Foundation
import UIKit

final class AppDiscoveryService: @unchecked Sendable {
    
    private let paths: JailbreakPaths
    private let filesystem: RootFilesystem
    private let logger: IconForgeLogger
    
    init(
        paths: JailbreakPaths = .detect(),
        filesystem: RootFilesystem = RootFilesystem(),
        logger: IconForgeLogger = .shared
    ) {
        self.paths = paths
        self.filesystem = filesystem
        self.logger = logger
    }
    
    func discoverAllApps() async -> [InstalledApp] {
        logger.info("Starting application discovery...")
        var apps: [InstalledApp] = []
        
        let userApps = discoverUserApps()
        apps.append(contentsOf: userApps)
        logger.info("Found \(userApps.count) user applications")
        
        let systemApps = discoverSystemApps()
        apps.append(contentsOf: systemApps)
        logger.info("Found \(systemApps.count) system applications")
        
        let jbApps = discoverJailbreakApps()
        apps.append(contentsOf: jbApps)
        logger.info("Found \(jbApps.count) jailbreak applications")
        
        var seen = Set<String>()
        var unique: [InstalledApp] = []
        for app in apps {
            if seen.insert(app.bundleIdentifier).inserted {
                unique.append(app)
            }
        }
        
        logger.info("Total unique applications: \(unique.count)")
        return unique
    }
    
    func loadIcon(for app: InstalledApp) -> UIImage? {
        if let iconPath = app.iconPath, let data = try? Data(contentsOf: iconPath) {
            return UIImage(data: data)
        }
        if let cached = UIImage(contentsOfFile: app.bundlePath.appendingPathComponent("AppIcon60x60@2x.png").path) {
            return cached
        }
        if let cached = UIImage(contentsOfFile: app.bundlePath.appendingPathComponent("AppIcon60x60@3x.png").path) {
            return cached
        }
        if let cached = UIImage(contentsOfFile: app.bundlePath.appendingPathComponent("Icon.png").path) {
            return cached
        }
        if let cached = UIImage(contentsOfFile: app.bundlePath.appendingPathComponent("icon.png").path) {
            return cached
        }
        let iconCandidates = [
            "AppIcon@2x.png", "AppIcon@3x.png", "AppIcon.png",
            "AppIcon-120.png", "AppIcon-167.png", "AppIcon-180.png",
            "AppIcon-1024.png"
        ]
        for candidate in iconCandidates {
            let path = app.bundlePath.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: path.path),
               let img = UIImage(contentsOfFile: path.path) {
                return img
            }
        }
        if let cfBundleIcons = readCFBundleIcons(from: app.bundlePath) {
            return cfBundleIcons
        }
        return nil
    }
    
    private func readCFBundleIcons(from bundlePath: URL) -> UIImage? {
        guard let infoPlist = NSDictionary(contentsOf: bundlePath.appendingPathComponent("Info.plist")) else {
            return nil
        }
        if let cfIconFile = infoPlist["CFBundleIconFile"] as? String {
            let iconPath = bundlePath.appendingPathComponent(cfIconFile)
            if let img = UIImage(contentsOfFile: iconPath.path) { return img }
        }
        if let cfIcons = infoPlist["CFBundleIcons"] as? [String: Any],
           let primary = cfIcons["CFBundlePrimaryIcon"] as? [String: Any] {
            if let files = primary["CFBundleIconFiles"] as? [String] {
                for file in files.sorted().reversed() {
                    let path = bundlePath.appendingPathComponent(file)
                    if let img = UIImage(contentsOfFile: path.path) { return img }
                }
            }
        }
        return nil
    }
    
    private func discoverUserApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fm = FileManager.default
        let searchPaths = [
            paths.varMobile.appendingPathComponent("Containers/Bundle/Application"),
            URL(fileURLWithPath: "/var/containers/Bundle/Application")
        ]
        for basePath in searchPaths {
            guard fm.fileExists(atPath: basePath.path) else { continue }
            guard let appDirs = try? fm.contentsOfDirectory(
                at: basePath,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) else { continue }
            for appDir in appDirs {
                guard let bundles = try? fm.contentsOfDirectory(
                    at: appDir,
                    includingPropertiesForKeys: nil
                ) else { continue }
                for bundle in bundles where bundle.pathExtension == "app" {
                    if let app = parseAppBundle(at: bundle, isSystem: false) {
                        apps.append(app)
                    }
                }
            }
        }
        return apps
    }
    
    private func discoverSystemApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fm = FileManager.default
        var searchPaths = [
            URL(fileURLWithPath: "/System/Applications"),
            paths.rootPrefix.appendingPathComponent("System/Applications"),
        ]
        let jbSystemApps = [
            paths.rootPrefix.appendingPathComponent("System/Applications"),
            URL(fileURLWithPath: "/var/jb/System/Applications"),
        ]
        searchPaths.append(contentsOf: jbSystemApps)
        for basePath in searchPaths {
            guard fm.fileExists(atPath: basePath.path) else { continue }
            guard let appDirs = try? fm.contentsOfDirectory(
                at: basePath,
                includingPropertiesForKeys: nil
            ) else { continue }
            for bundle in appDirs where bundle.pathExtension == "app" {
                if let app = parseAppBundle(at: bundle, isSystem: true) {
                    apps.append(app)
                }
            }
        }
        return apps
    }
    
    private func discoverJailbreakApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fm = FileManager.default
        let jbPaths = [
            paths.rootPrefix.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/var/jb/Applications"),
        ]
        for basePath in jbPaths {
            guard fm.fileExists(atPath: basePath.path) else { continue }
            guard let appDirs = try? fm.contentsOfDirectory(
                at: basePath,
                includingPropertiesForKeys: nil
            ) else { continue }
            for bundle in appDirs where bundle.pathExtension == "app" {
                if let app = parseAppBundle(at: bundle, isSystem: false) {
                    apps.append(app)
                }
            }
        }
        return apps
    }
    
    private func parseAppBundle(at bundlePath: URL, isSystem: Bool) -> InstalledApp? {
        let infoPlist = bundlePath.appendingPathComponent("Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlist) else { return nil }
        guard let bundleId = plist["CFBundleIdentifier"] as? String else { return nil }
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? (bundlePath.deletingPathExtension().lastPathComponent)
        let version = plist["CFBundleVersion"] as? String
        let shortVersion = plist["CFBundleShortVersionString"] as? String
        let iconPath = findBestIconPath(in: bundlePath)
        let isUserApp = !isSystem
        return InstalledApp(
            bundleIdentifier: bundleId,
            displayName: name,
            bundlePath: bundlePath,
            iconPath: iconPath,
            isSystemApp: isSystem,
            isUserApp: isUserApp,
            version: version,
            shortVersion: shortVersion
        )
    }
    
    private func findBestIconPath(in bundlePath: URL) -> URL? {
        let fm = FileManager.default
        let iconSizes = ["1024x1024", "180x180", "167x167", "120x120", "76x76", "60x60"]
        for size in iconSizes {
            for scale in ["@3x", "@2x", ""] {
                let name = "AppIcon\(size)@\(scale)".replacingOccurrences(of: "@", with: scale.isEmpty ? "" : "@")
                let candidates = [
                    "AppIcon\(size)\(scale).png",
                    "Icon-\(size)\(scale).png",
                    "icon\(size)\(scale).png"
                ]
                for candidate in candidates {
                    let path = bundlePath.appendingPathComponent(candidate)
                    if fm.fileExists(atPath: path.path) { return path }
                }
            }
        }
        if let cfBundleIcons = readCFBundleIconsPath(from: bundlePath) {
            return cfBundleIcons
        }
        let genericNames = ["AppIcon.png", "Icon.png", "icon.png", "icon@2x.png", "icon@3x.png"]
        for name in genericNames {
            let path = bundlePath.appendingPathComponent(name)
            if fm.fileExists(atPath: path.path) { return path }
        }
        return nil
    }
    
    private func readCFBundleIconsPath(from bundlePath: URL) -> URL? {
        guard let infoPlist = NSDictionary(contentsOf: bundlePath.appendingPathComponent("Info.plist")) else {
            return nil
        }
        if let cfIconFile = infoPlist["CFBundleIconFile"] as? String {
            let iconPath = bundlePath.appendingPathComponent(cfIconFile)
            if FileManager.default.fileExists(atPath: iconPath.path) { return iconPath }
        }
        if let cfIcons = infoPlist["CFBundleIcons"] as? [String: Any],
           let primary = cfIcons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String] {
            for file in files.sorted().reversed() {
                let path = bundlePath.appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: path.path) { return path }
            }
        }
        return nil
    }
}

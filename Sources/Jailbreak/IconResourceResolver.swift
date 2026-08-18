import Foundation
import UIKit

struct ResolvedIconResource: Sendable {
    let path: URL
    let scale: CGFloat
    let size: CGSize
    let filename: String
}

struct IconResourceResolver: Sendable {

    static func resolveIconTargets(for app: InstalledApp) -> [URL] {
        let fm = FileManager.default
        var targets: [URL] = []

        if let plistTargets = resolveFromInfoPlist(bundlePath: app.bundlePath) {
            targets.append(contentsOf: plistTargets)
        }

        let commonNames = [
            "AppIcon60x60@2x.png",
            "AppIcon60x60@3x.png",
            "AppIcon-120.png",
            "AppIcon-180.png",
            "AppIcon-1024.png",
            "AppIcon.png",
        ]
        for name in commonNames {
            let path = app.bundlePath.appendingPathComponent(name)
            if fm.fileExists(atPath: path.path) && !targets.contains(path) {
                targets.append(path)
            }
        }

        if targets.isEmpty {
            let fallback = app.bundlePath.appendingPathComponent("AppIcon.png")
            targets.append(fallback)
        }

        return targets
    }

    static func resolveBestIconPath(for app: InstalledApp) -> URL? {
        let targets = resolveIconTargets(for: app)
        return targets.first
    }

    static func readIconResources(bundlePath: URL) -> [ResolvedIconResource] {
        var resources: [ResolvedIconResource] = []
        let fm = FileManager.default

        if let plistResources = readFromInfoPlist(bundlePath: bundlePath) {
            resources.append(contentsOf: plistResources)
        }

        let patternResources = readFromCommonPatterns(bundlePath: bundlePath)
        for res in patternResources {
            if !resources.contains(where: { $0.path == res.path }) {
                resources.append(res)
            }
        }

        return resources
    }

    static func hasAssetCatalog(bundlePath: URL) -> Bool {
        let assetPath = bundlePath.appendingPathComponent("Assets.car")
        return FileManager.default.fileExists(atPath: assetPath.path)
    }

    static func hasCFBundleIcons(bundlePath: URL) -> Bool {
        guard let infoPlist = NSDictionary(contentsOf: bundlePath.appendingPathComponent("Info.plist")) else {
            return false
        }
        if let cfIcons = infoPlist["CFBundleIcons"] as? [String: Any] {
            return cfIcons["CFBundlePrimaryIcon"] != nil
        }
        return false
    }

    private static func resolveFromInfoPlist(bundlePath: URL) -> [URL]? {
        guard let infoPlist = NSDictionary(contentsOf: bundlePath.appendingPathComponent("Info.plist")) else {
            return nil
        }
        var urls: [URL] = []

        if let cfIconFile = infoPlist["CFBundleIconFile"] as? String {
            let iconPath = bundlePath.appendingPathComponent(cfIconFile)
            if FileManager.default.fileExists(atPath: iconPath.path) {
                urls.append(iconPath)
            }
        }

        let iconKeys = ["CFBundleIcons", "CFBundleIcons~ipad"]
        for key in iconKeys {
            if let cfIcons = infoPlist[key] as? [String: Any],
               let primary = cfIcons["CFBundlePrimaryIcon"] as? [String: Any] {
                if let files = primary["CFBundleIconFiles"] as? [String] {
                    for file in files.sorted().reversed() {
                        let path = bundlePath.appendingPathComponent(file)
                        if FileManager.default.fileExists(atPath: path.path) && !urls.contains(path) {
                            urls.append(path)
                        }
                    }
                }
            }
        }

        return urls.isEmpty ? nil : urls
    }

    private static func readFromInfoPlist(bundlePath: URL) -> [ResolvedIconResource]? {
        guard let infoPlist = NSDictionary(contentsOf: bundlePath.appendingPathComponent("Info.plist")) else {
            return nil
        }
        var resources: [ResolvedIconResource] = []

        let iconKeys = ["CFBundleIcons", "CFBundleIcons~ipad"]
        for key in iconKeys {
            guard let cfIcons = infoPlist[key] as? [String: Any] else { continue }
            let groups: [[String: Any]] = {
                var result: [[String: Any]] = []
                if let primary = cfIcons["CFBundlePrimaryIcon"] as? [String: Any] {
                    result.append(primary)
                }
                for (k, v) in cfIcons {
                    if k != "CFBundlePrimaryIcon", let dict = v as? [String: Any] {
                        result.append(dict)
                    }
                }
                return result
            }()

            for group in groups {
                guard let files = group["CFBundleIconFiles"] as? [String] else { continue }
                for file in files {
                    let path = bundlePath.appendingPathComponent(file)
                    if FileManager.default.fileExists(atPath: path.path) {
                        let scale = extractScale(from: file)
                        let size = estimateSize(from: file)
                        resources.append(ResolvedIconResource(
                            path: path, scale: scale, size: size, filename: file
                        ))
                    }
                }
            }
        }

        return resources.isEmpty ? nil : resources
    }

    private static func readFromCommonPatterns(bundlePath: URL) -> [ResolvedIconResource] {
        var resources: [ResolvedIconResource] = []
        let fm = FileManager.default
        let patterns: [(name: String, scale: CGFloat, size: CGSize)] = [
            ("AppIcon60x60@2x.png", 2, CGSize(width: 60, height: 60)),
            ("AppIcon60x60@3x.png", 3, CGSize(width: 60, height: 60)),
            ("AppIcon76x76@2x~ipad.png", 2, CGSize(width: 76, height: 76)),
            ("AppIcon-120.png", 2, CGSize(width: 60, height: 60)),
            ("AppIcon-180.png", 3, CGSize(width: 60, height: 60)),
            ("AppIcon-1024.png", 1, CGSize(width: 1024, height: 1024)),
            ("AppIcon.png", 1, CGSize(width: 1024, height: 1024)),
            ("Icon.png", 1, CGSize(width: 1024, height: 1024)),
        ]
        for pattern in patterns {
            let path = bundlePath.appendingPathComponent(pattern.name)
            if fm.fileExists(atPath: path.path) {
                resources.append(ResolvedIconResource(
                    path: path, scale: pattern.scale, size: pattern.size, filename: pattern.name
                ))
            }
        }
        return resources
    }

    private static func extractScale(from filename: String) -> CGFloat {
        if filename.contains("@3x") { return 3 }
        if filename.contains("@2x") { return 2 }
        return 1
    }

    private static func estimateSize(from filename: String) -> CGSize {
        let name = (filename as NSString).deletingPathExtension
        if name.contains("1024") { return CGSize(width: 1024, height: 1024) }
        if name.contains("180") { return CGSize(width: 60, height: 60) }
        if name.contains("120") { return CGSize(width: 60, height: 60) }
        if name.contains("76") { return CGSize(width: 76, height: 76) }
        if name.contains("60") { return CGSize(width: 60, height: 60) }
        return CGSize(width: 1024, height: 1024)
    }
}

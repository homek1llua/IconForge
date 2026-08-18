import Foundation

struct JailbreakPaths: Sendable {
    let rootPrefix: URL
    let systemLibrary: URL
    let applications: URL
    let preferences: URL
    let caches: URL
    let varMobile: URL
    let launchDaemons: URL
    let libraryPreferenceBundles: URL
    let usrLib: URL
    let privateVarTmp: URL
    let iconCacheDirectory: URL

    private static let rootlessPrefixes: [URL] = [
        URL(fileURLWithPath: "/var/jb"),
        URL(fileURLWithPath: "/var/Liy"),
    ]

    static func detect() -> JailbreakPaths {
        let fm = FileManager.default

        for prefix in rootlessPrefixes {
            let sysLib = prefix.appendingPathComponent("System/Library")
            if fm.fileExists(atPath: sysLib.path) {
                return JailbreakPaths(
                    rootPrefix: prefix,
                    systemLibrary: sysLib,
                    applications: prefix.appendingPathComponent("Applications"),
                    preferences: prefix.appendingPathComponent("Library/PreferenceBundles"),
                    caches: prefix.appendingPathComponent("Library/Caches"),
                    varMobile: URL(fileURLWithPath: "/var/mobile"),
                    launchDaemons: prefix.appendingPathComponent("Library/LaunchDaemons"),
                    libraryPreferenceBundles: prefix.appendingPathComponent("Library/PreferenceBundles"),
                    usrLib: prefix.appendingPathComponent("usr/lib"),
                    privateVarTmp: URL(fileURLWithPath: "/private/var/tmp"),
                    iconCacheDirectory: prefix.appendingPathComponent("Library/Caches/com.apple.IconsCache")
                )
            }
        }

        let systemLibrary = URL(fileURLWithPath: "/System/Library")
        if fm.fileExists(atPath: systemLibrary.path) {
            return JailbreakPaths(
                rootPrefix: URL(fileURLWithPath: "/"),
                systemLibrary: systemLibrary,
                applications: URL(fileURLWithPath: "/Applications"),
                preferences: URL(fileURLWithPath: "/Library/PreferenceBundles"),
                caches: URL(fileURLWithPath: "/Library/Caches"),
                varMobile: URL(fileURLWithPath: "/var/mobile"),
                launchDaemons: URL(fileURLWithPath: "/Library/LaunchDaemons"),
                libraryPreferenceBundles: URL(fileURLWithPath: "/Library/PreferenceBundles"),
                usrLib: URL(fileURLWithPath: "/usr/lib"),
                privateVarTmp: URL(fileURLWithPath: "/private/var/tmp"),
                iconCacheDirectory: URL(fileURLWithPath: "/Library/Caches/com.apple.IconsCache")
            )
        }

        return JailbreakPaths(
            rootPrefix: URL(fileURLWithPath: "/var/mobile"),
            systemLibrary: URL(fileURLWithPath: "/var/mobile/.system/Library"),
            applications: URL(fileURLWithPath: "/var/mobile/Applications"),
            preferences: URL(fileURLWithPath: "/var/mobile/Library/Preferences"),
            caches: URL(fileURLWithPath: "/var/mobile/Library/Caches"),
            varMobile: URL(fileURLWithPath: "/var/mobile"),
            launchDaemons: URL(fileURLWithPath: "/var/mobile/Library/LaunchDaemons"),
            libraryPreferenceBundles: URL(fileURLWithPath: "/var/mobile/Library/PreferenceBundles"),
            usrLib: URL(fileURLWithPath: "/var/mobile/usr/lib"),
            privateVarTmp: URL(fileURLWithPath: "/var/mobile/tmp"),
            iconCacheDirectory: URL(fileURLWithPath: "/var/mobile/Library/Caches/com.apple.IconsCache")
        )
    }

    func resolveBundlePath(for bundleIdentifier: String, isSystemApp: Bool) -> URL? {
        let fm = FileManager.default
        if isSystemApp {
            let systemPath = rootPrefix.appendingPathComponent("System/Applications/\(bundleIdentifier).app")
            if fm.fileExists(atPath: systemPath.path) { return systemPath }
            let rootPath = applications.appendingPathComponent("\(bundleIdentifier).app")
            if fm.fileExists(atPath: rootPath.path) { return rootPath }
        }
        let userDomains = [
            varMobile.appendingPathComponent("Containers/Bundle/Application"),
            varMobile.appendingPathComponent("Application"),
            URL(fileURLWithPath: "/var/containers/Bundle/Application")
        ]
        for domain in userDomains {
            guard fm.fileExists(atPath: domain.path) else { continue }
            if let apps = try? fm.contentsOfDirectory(at: domain, includingPropertiesForKeys: nil) {
                for appDir in apps {
                    if let bundles = try? fm.contentsOfDirectory(at: appDir, includingPropertiesForKeys: nil) {
                        for bundle in bundles where bundle.pathExtension == "app" {
                            let infoPlist = bundle.appendingPathComponent("Info.plist")
                            if let plist = NSDictionary(contentsOf: infoPlist),
                               plist["CFBundleIdentifier"] as? String == bundleIdentifier {
                                return bundle
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    func iconResourcePaths(for appBundle: URL) -> [URL] {
        let fm = FileManager.default
        var paths: [URL] = []
        let iconNameCandidates = ["AppIcon", "Icon", "icon"]
        for name in iconNameCandidates {
            let assetPath = appBundle.appendingPathComponent("\(name).appiconset")
            if fm.fileExists(atPath: assetPath.path) { paths.append(assetPath) }
            let pngPath = appBundle.appendingPathComponent("\(name).png")
            if fm.fileExists(atPath: pngPath.path) { paths.append(pngPath) }
            let largePng = appBundle.appendingPathComponent("\(name)-120.png")
            if fm.fileExists(atPath: largePng.path) { paths.append(largePng) }
        }
        if let resources = fm.contentsOfDirectory(at: appBundle, includingPropertiesForKeys: nil) {
            let iconResources = resources.filter { resource in
                let name = resource.deletingPathExtension().lastPathComponent.lowercased()
                return name.hasSuffix("icon") || name == "appicon"
            }
            paths.append(contentsOf: iconResources)
        }
        if let infoPlist = NSDictionary(contentsOf: appBundle.appendingPathComponent("Info.plist")) {
            if let cfIcon = infoPlist["CFBundleIconFile"] as? String {
                let iconPath = appBundle.appendingPathComponent(cfIcon)
                if fm.fileExists(atPath: iconPath.path) { paths.append(iconPath) }
            }
            if let cfIcons = infoPlist["CFBundleIcons"] as? [String: Any],
               let primary = cfIcons["CFBundlePrimaryIcon"] as? [String: Any],
               let files = primary["CFBundleIconFiles"] as? [String],
               let first = files.first {
                let iconPath = appBundle.appendingPathComponent(first)
                if fm.fileExists(atPath: iconPath.path) { paths.append(iconPath) }
            }
        }
        return paths
    }
}

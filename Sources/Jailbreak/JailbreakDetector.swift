import Foundation

enum JailbreakEnvironment: String, Sendable {
    case unsupported = "Unsupported"
    case jailed = "Jailed"
    case jailbroken = "Jailbroken"
    case jailbrokenRootless = "Rootless"
    case jailbrokenRootful = "Rootful"
}

enum JailbreakType: String, Sendable {
    case unc0ver = "unc0ver"
    case checkra1n = "checkra1n"
    case dopamine = "Dopamine"
    case palera1n = "palera1n"
    case trollstore = "TrollStore"
    case filza = "Filza"
    case xinaA15 = "XinaA15"
    case seroton = "Serotonin"
    case bootstrap = "Bootstrap"
    case unknown = "Unknown"
    case none = "None"
}

enum RequiredCapability: String, CaseIterable, Sendable {
    case rootAccess = "Root Access"
    case fileSystemWrite = "Filesystem Write"
    case applicationDiscovery = "Application Discovery"
    case iconModification = "Icon Modification"
    case cacheRefresh = "Cache Refresh"
    case respring = "Respring"
    case launchServicesAccess = "LaunchServices Access"
}

struct JailbreakStatus: Sendable {
    let environment: JailbreakEnvironment
    let jailbreakType: JailbreakType
    let rootAccessAvailable: Bool
    let supportedCapabilities: Set<RequiredCapability>
    let availableUtilities: [String: Bool]
    let rootPath: URL
    let errorMessages: [String]

    func supports(_ capability: RequiredCapability) -> Bool {
        supportedCapabilities.contains(capability)
    }

    var capabilitiesSummary: String {
        supportedCapabilities.map(\.rawValue).joined(separator: ", ")
    }
}

final class JailbreakDetector: Sendable {

    static let shared = JailbreakDetector()

    private init() {}

    func detectEnvironment() -> JailbreakStatus {
        let rootPath = detectRootPath()
        let environment = detectEnvironmentType(rootPath: rootPath)
        let jailbreakType = detectJailbreakType()
        let rootAccess = checkRootAccess()
        let utilities = findAvailableUtilities()
        let capabilities = determineCapabilities(
            environment: environment,
            rootAccess: rootAccess,
            utilities: utilities
        )
        var errors: [String] = []
        if environment == .unsupported {
            errors.append("Device appears to be jailed or running an unsupported jailbreak.")
        }
        if !rootAccess && environment != .jailed {
            errors.append("Root filesystem access is not available.")
        }
        return JailbreakStatus(
            environment: environment,
            jailbreakType: jailbreakType,
            rootAccessAvailable: rootAccess,
            supportedCapabilities: capabilities,
            availableUtilities: utilities,
            rootPath: rootPath,
            errorMessages: errors
        )
    }

    private func detectRootPath() -> URL {
        let rootlessPaths = [
            "/var/jb",
            "/private/preboot/*/procursus",
            "/var/Liy/",
            "/var/jb/usr"
        ]
        for path in rootlessPaths {
            let expanded = expandGlob(path)
            if let url = expanded, FileManager.default.fileExists(atPath: url.path) {
                return url.deletingLastPathComponent()
            }
        }
        let systemPaths = [
            "/System/Library",
            "/usr/lib",
            "/Library"
        ]
        for path in systemPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return URL(fileURLWithPath: "/")
            }
        }
        if access("/private/var/tmp/.jb-root-", F_OK) == 0 ||
           access("/var/mobile/Library/Preferences", W_OK) == 0 {
            return URL(fileURLWithPath: "/")
        }
        return URL(fileURLWithPath: "/var/jb")
    }

    private func expandGlob(_ pattern: String) -> URL? {
        var result = glob_t()
        defer { globfree(&result) }
        let ret = pattern.withCString { cString in
            glob(cString, 0, nil, &result)
        }
        guard ret == 0, result.gl_pathc > 0 else { return nil }
        guard let cPath = result.gl_pathv[0] else { return nil }
        let path = String(cString: cPath)
        return URL(fileURLWithPath: path)
    }

    private func detectEnvironmentType(rootPath: URL) -> JailbreakEnvironment {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/System/Library") ||
           fm.fileExists(atPath: "/var/jb/usr/lib") {
            return .jailbrokenRootless
        }
        if fm.fileExists(atPath: "/var/mobile/.cydia_no_stash") ||
           fm.fileExists(atPath: "/Applications/Cydia.app") {
            return .jailbrokenRootful
        }
        if fm.fileExists(atPath: "/var/jb") || fm.fileExists(atPath: "/var/Liy") {
            return .jailbrokenRootless
        }
        if fm.fileExists(atPath: "/System/Library/LaunchDaemons"),
           fm.isReadableFile(atPath: "/private/etc/apt") {
            return .jailbrokenRootful
        }
        if fm.fileExists(atPath: "/var/binpack") {
            return .jailbrokenRootful
        }
        if access("/private/var/tmp", W_OK) == 0,
           fm.fileExists(atPath: "/usr/bin/ssh") {
            return .jailbrokenRootful
        }
        if fm.fileExists(atPath: "/var/mobile/Library/Preferences") {
            if access("/private/var/tmp/.jb-root-", F_OK) == 0 {
                return .jailbrokenRootless
            }
            return .jailbrokenRootful
        }
        return .jailed
    }

    private func detectJailbreakType() -> JailbreakType {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/usr/bin/dopamine") ||
           fm.fileExists(atPath: "/var/jb/basebin") {
            return .dopamine
        }
        if fm.fileExists(atPath: "/var/jb/usr/bin/palera1nd") ||
           fm.fileExists(atPath: "/cores/binpack") {
            return .palera1n
        }
        if fm.fileExists(atPath: "/usr/bin/unc0ver") ||
           fm.fileExists(atPath: "/var/jailbreak") {
            return .unc0ver
        }
        if fm.fileExists(atPath: "/usr/bin/checkra1n") ||
           fm.fileExists(atPath: "/var/checkra1n.dmg") {
            return .checkra1n
        }
        if fm.fileExists(atPath: "/var/containers/Bundle/Application/*/TrollStore.app") ||
           fm.fileExists(atPath: "/var/mobile/Library/TrollStore") {
            return .trollstore
        }
        if fm.fileExists(atPath: "/var/Liy/xina") {
            return .xinaA15
        }
        if fm.fileExists(atPath: "/private/var/stash") ||
           fm.fileExists(atPath: "/Applications/Sileo.app") ||
           fm.fileExists(atPath: "/Applications/Zebra.app") {
            return .unknown
        }
        if access("/private/var/tmp", W_OK) == 0 {
            return .bootstrap
        }
        return .none
    }

    private func checkRootAccess() -> Bool {
        if getuid() == 0 { return true }
        if FileManager.default.isReadableFile(atPath: "/private/etc/master.passwd") { return true }
        if FileManager.default.isWritableFile(atPath: "/private/var/tmp") { return true }
        let testPath = "/private/var/tmp/.iconforge_test_\(UUID().uuidString)"
        if FileManager.default.createFile(atPath: testPath, contents: Data()) {
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        }
        return false
    }

    private func findAvailableUtilities() -> [String: Bool] {
        let utilities = [
            "uicache", "sbreload", "killall", "launchctl",
            "dpkg", "apt", "ssh", "su", "bash", "zsh",
            "cycript", "class-dump", "plutil",
            "filza", "posterboard", "iconcache"
        ]
        var results: [String: Bool] = [:]
        let paths = ["/usr/bin", "/usr/sbin", "/usr/local/bin", "/var/jb/usr/bin", "/var/jb/usr/sbin"]
        for util in utilities {
            var found = false
            for path in paths {
                if FileManager.default.isExecutableFile(atPath: "\(path)/\(util)") {
                    found = true
                    break
                }
            }
            results[util] = found
        }
        return results
    }

    private func determineCapabilities(
        environment: JailbreakEnvironment,
        rootAccess: Bool,
        utilities: [String: Bool]
    ) -> Set<RequiredCapability> {
        var capabilities = Set<RequiredCapability>()
        guard environment != .jailed else { return capabilities }
        if rootAccess {
            capabilities.insert(.rootAccess)
            capabilities.insert(.fileSystemWrite)
        }
        if rootAccess || environment != .jailed {
            capabilities.insert(.applicationDiscovery)
            capabilities.insert(.iconModification)
            capabilities.insert(.cacheRefresh)
            capabilities.insert(.respring)
            capabilities.insert(.launchServicesAccess)
        }
        return capabilities
    }
}

import Foundation

final class LaunchServicesManager: @unchecked Sendable {

    private let paths: JailbreakPaths

    init(paths: JailbreakPaths = .detect()) {
        self.paths = paths
    }

    func refreshLaunchServices() {
        let uicachePaths = ["/usr/bin/uicache", "/var/jb/usr/bin/uicache", "/usr/local/bin/uicache"]
        for uicachePath in uicachePaths {
            if FileManager.default.isExecutableFile(atPath: uicachePath) {
                runCommand(uicachePath, arguments: ["-a"])
                return
            }
        }
        runCommand("/usr/bin/killall", arguments: ["-HUP", "backboardd"])
        runCommand("/usr/bin/killall", arguments: ["-HUP", "SpringBoard"])
    }

    func refreshIconForBundle(_ bundleIdentifier: String) {
        let uicachePaths = ["/usr/bin/uicache", "/var/jb/usr/bin/uicache", "/usr/local/bin/uicache"]
        for uicachePath in uicachePaths {
            if FileManager.default.isExecutableFile(atPath: uicachePath) {
                let bundlePath = paths.resolveBundlePath(for: bundleIdentifier, isSystemApp: false)
                if let bundlePath {
                    runCommand(uicachePath, arguments: ["-p", bundlePath.path])
                } else {
                    runCommand(uicachePath, arguments: ["-a"])
                }
                return
            }
        }
        runCommand("/usr/bin/killall", arguments: ["-HUP", "backboardd"])
    }

    func iconStateURL() -> URL? {
        let candidates = [
            paths.varMobile.appendingPathComponent("Library/SpringBoard/IconState.plist"),
            paths.caches.appendingPathComponent("com.apple.IconsCache/IconState.plist"),
            paths.varMobile.appendingPathComponent("Library/Preferences/com.apple.springboard.plist"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func readIconState() -> [String: Any]? {
        guard let url = iconStateURL() else { return nil }
        return NSDictionary(contentsOf: url) as? [String: Any]
    }

    func readIconCacheManifest() -> [String: Any]? {
        let candidates = [
            paths.caches.appendingPathComponent("com.apple.IconsCache/manifest.plist"),
            paths.varMobile.appendingPathComponent("Library/Caches/com.apple.IconsCache/manifest.plist"),
            URL(fileURLWithPath: "/var/mobile/Library/Caches/com.apple.IconsCache/manifest.plist"),
        ]
        for url in candidates {
            if let dict = NSDictionary(contentsOf: url) as? [String: Any] {
                return dict
            }
        }
        return nil
    }

    @discardableResult
    private func runCommand(_ path: String, arguments: [String]) -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, process.terminationStatus)
        } catch {
            return ("", -1)
        }
    }
}

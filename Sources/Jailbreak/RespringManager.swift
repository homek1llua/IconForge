import Foundation

enum RespringMethod: String, CaseIterable, Identifiable, Sendable {
    case refreshIcons = "Refresh Icons"
    case restartSpringBoard = "Restart SpringBoard"
    case fullRespring = "Full Respring"
    case sbreload = "sbreload"
    case backboardd = "Restart backboardd"

    var id: String { rawValue }

    var isDestructive: Bool {
        self == .fullRespring || self == .restartSpringBoard
    }

    var description: String {
        switch self {
        case .refreshIcons: return "Refreshes the icon cache without restarting SpringBoard."
        case .restartSpringBoard: return "Restarts SpringBoard. Your device will briefly show the lock screen."
        case .fullRespring: return "Full respring including all daemons. Most thorough but most disruptive."
        case .sbreload: return "Uses sbreload for a cleaner restart of SpringBoard."
        case .backboardd: return "Restarts backboardd which handles icon display."
        }
    }
}

enum RespringError: Error, LocalizedError {
    case methodNotAvailable
    case commandFailed(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .methodNotAvailable: return "The selected respring method is not available on this device."
        case .commandFailed(let msg): return "Respring command failed: \(msg)"
        case .permissionDenied: return "Permission denied for respring operation."
        }
    }
}

final class RespringManager: @unchecked Sendable {

    private let paths: JailbreakPaths
    private let availableMethods: Set<RespringMethod>

    init(paths: JailbreakPaths = .detect()) {
        self.paths = paths
        self.availableMethods = Self.detectAvailableMethods(paths: paths)
    }

    func performRespring(_ method: RespringMethod) throws {
        guard availableMethods.contains(method) else {
            throw RespringError.methodNotAvailable
        }
        switch method {
        case .refreshIcons:
            refreshIcons()
        case .restartSpringBoard:
            restartSpringBoard()
        case .fullRespring:
            fullRespring()
        case .sbreload:
            runSBReload()
        case .backboardd:
            restartBackboardd()
        }
    }

    func availableRespringMethods() -> [RespringMethod] {
        Array(availableMethods).sorted { $0.rawValue < $1.rawValue }
    }

    private func refreshIcons() {
        let uicachePaths = ["/usr/bin/uicache", "/var/jb/usr/bin/uicache", "/usr/local/bin/uicache"]
        for path in uicachePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                runCommand(path, arguments: ["-a"])
                return
            }
        }
    }

    private func restartSpringBoard() {
        if runCommand("/usr/bin/killall", arguments: ["-HUP", "SpringBoard"]).exitCode == 0 { return }
        if runCommand("/var/jb/usr/bin/killall", arguments: ["-HUP", "SpringBoard"]).exitCode == 0 { return }
        runCommand("/usr/bin/killall", arguments: ["SpringBoard"])
    }

    private func fullRespring() {
        let methods = [
            "/usr/sbin/sbreload",
            "/var/jb/usr/sbin/sbreload",
            "/usr/bin/sbreload",
            "/var/jb/usr/bin/sbreload"
        ]
        for method in methods {
            if FileManager.default.isExecutableFile(atPath: method) {
                runCommand(method, arguments: [])
                return
            }
        }
        runCommand("/usr/bin/killall", arguments: ["-9", "SpringBoard"])
    }

    private func runSBReload() {
        let methods = ["/usr/sbin/sbreload", "/var/jb/usr/sbin/sbreload"]
        for method in methods {
            if FileManager.default.isExecutableFile(atPath: method) {
                runCommand(method, arguments: [])
                return
            }
        }
        restartSpringBoard()
    }

    private func restartBackboardd() {
        if runCommand("/usr/bin/killall", arguments: ["-9", "backboardd"]).exitCode == 0 { return }
        runCommand("/usr/sbin/killall", arguments: ["-9", "backboardd"])
    }

    private static func detectAvailableMethods(paths: JailbreakPaths) -> Set<RespringMethod> {
        var methods = Set<RespringMethod>()
        let fm = FileManager.default
        let uicachePaths = ["/usr/bin/uicache", "/var/jb/usr/bin/uicache"]
        for path in uicachePaths {
            if fm.isExecutableFile(atPath: path) { methods.insert(.refreshIcons); break }
        }
        if fm.isExecutableFile(atPath: "/usr/bin/killall") || fm.isExecutableFile(atPath: "/usr/sbin/killall") {
            methods.insert(.restartSpringBoard)
            methods.insert(.fullRespring)
            methods.insert(.backboardd)
        }
        let sbreloadPaths = ["/usr/sbin/sbreload", "/var/jb/usr/sbin/sbreload"]
        for path in sbreloadPaths {
            if fm.isExecutableFile(atPath: path) { methods.insert(.sbreload); break }
        }
        return methods
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

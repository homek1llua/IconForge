import Foundation
import Darwin

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
        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(path)]
        for arg in arguments {
            argv.append(strdup(arg))
        }
        defer { argv.forEach { $0?.deallocate() } }

        let pipefds: [Int32] = [0, 0]
        var fds = pipefds
        guard pipe(&fds) == 0 else { return ("", -1) }

        var pid: pid_t = 0
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_addclose(&fileActions, fds[0])
        posix_spawn_file_actions_adddup2(&fileActions, fds[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, fds[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, fds[1])

        let status = posix_spawn(&pid, path, &fileActions, nil, argv, nil)
        posix_spawn_file_actions_destroy(&fileActions)

        close(fds[1])

        guard status == 0 else {
            close(fds[0])
            return ("", status)
        }

        var outputData = Data()
        var buffer = [UInt8](repeating: 0, count: 512)
        while read(fds[0], &buffer, buffer.count) > 0 {
            outputData.append(buffer, count: buffer.count)
        }
        close(fds[0])

        var exitCode: Int32 = 0
        waitpid(pid, &exitCode, 0)

        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (output, WEXITSTATUS(exitCode))
    }
}

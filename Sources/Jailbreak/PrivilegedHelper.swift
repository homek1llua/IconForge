import Foundation
import Darwin

struct PrivilegedWriteResult: Sendable {
    let success: Bool
    let outputPath: String
    let sha256Hash: String?
    let errorMessage: String?
    let diagnostics: PrivilegedDiagnostics
}

struct PrivilegedReadResult: Sendable {
    let success: Bool
    let data: Data?
    let errorMessage: String?
    let diagnostics: PrivilegedDiagnostics
}

struct PrivilegedDiagnostics: Sendable {
    let uid: uid_t
    let gid: gid_t
    let effectiveUID: uid_t
    let shellPath: String
    let shellExists: Bool
    let shellExecutable: Bool
    let setuidAttempted: Bool
    let setuidSucceeded: Bool
    let errnoValue: Int32
    let errnoMessage: String

    var summary: String {
        """
        UID: \(uid), EUID: \(effectiveUID), GID: \(gid)
        Shell: \(shellPath) (exists: \(shellExists), executable: \(shellExecutable))
        setuid(0) attempted: \(setuidAttempted), succeeded: \(setuidSucceeded)
        errno: \(errnoValue) (\(errnoMessage))
        """
    }
}

enum PrivilegedHelper {

    private static let shellPaths = [
        "/bin/sh",
        "/usr/bin/sh",
        "/var/jb/bin/sh",
        "/var/jb/usr/bin/sh",
    ]

    private static var cachedShell: String?

    private static func findShell() -> String? {
        if let cached = cachedShell, access(cached, X_OK) == 0 { return cached }
        for path in shellPaths {
            if access(path, X_OK) == 0 {
                cachedShell = path
                return path
            }
        }
        return nil
    }

    static func escalatePrivileges() -> Bool {
        guard getuid() != 0 else { return true }
        setuid(0)
        if getuid() == 0 { return true }
        seteuid(0)
        if geteuid() == 0 { return true }
        return false
    }

    static func buildDiagnostics(shell: String?) -> PrivilegedDiagnostics {
        let shellPath = shell ?? "none"
        return PrivilegedDiagnostics(
            uid: getuid(),
            gid: getgid(),
            effectiveUID: geteuid(),
            shellPath: shellPath,
            shellExists: shell.map { access($0, F_OK) == 0 } ?? false,
            shellExecutable: shell.map { access($0, X_OK) == 0 } ?? false,
            setuidAttempted: false,
            setuidSucceeded: getuid() == 0,
            errnoValue: 0,
            errnoMessage: "none"
        )
    }

    static func writeFile(
        data: Data,
        to destination: URL,
        backupOriginal: Bool = true,
        logger: IconForgeLogger = .shared
    ) throws -> PrivilegedWriteResult {
        let fm = FileManager.default
        let shell = findShell()
        var diags = buildDiagnostics(shell: shell)

        guard let shell else {
            diags = PrivilegedDiagnostics(
                uid: getuid(), gid: getgid(), effectiveUID: geteuid(),
                shellPath: "none", shellExists: false, shellExecutable: false,
                setuidAttempted: false, setuidSucceeded: getuid() == 0,
                errnoValue: 0, errnoMessage: "no shell found"
            )
            let msg = "No shell binary found at any of: \(shellPaths.joined(separator: ", "))"
            logger.error(msg)
            return PrivilegedWriteResult(
                success: false, outputPath: destination.path, sha256Hash: nil,
                errorMessage: msg, diagnostics: diags
            )
        }

        let targetDir = destination.deletingLastPathComponent().path
        let targetPath = destination.path

        if backupOriginal && fm.fileExists(atPath: targetPath) {
            let backupPath = "\(targetPath).iconforge_bak_\(UUID().uuidString)"
            let backupCmd = "cp \"\(targetPath)\" \"\(backupPath)\" 2>/dev/null || true"
            let _ = executeShellScript(commands: [backupCmd], logger: logger)
        }

        let tmpDir = StorageManager.tempDirectory()
        let tmpFile = tmpDir.appendingPathComponent("iconforge_\(UUID().uuidString).png")
        try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        try data.write(to: tmpFile)

        let commands = [
            "mkdir -p \"\(targetDir)\"",
            "rm -f \"\(targetPath)\" 2>/dev/null || true",
            "cp \"\(tmpFile.path)\" \"\(targetPath)\"",
            "chmod 644 \"\(targetPath)\"",
            "rm -f \"\(tmpFile.path)\" 2>/dev/null || true",
        ]

        let result = executeShellScript(commands: commands, logger: logger)
        try? fm.removeItem(at: tmpFile)

        diags = PrivilegedDiagnostics(
            uid: getuid(), gid: getgid(), effectiveUID: geteuid(),
            shellPath: shell, shellExists: true, shellExecutable: true,
            setuidAttempted: true, setuidSucceeded: getuid() == 0,
            errnoValue: result.rawStatus,
            errnoMessage: result.rawStatus == 0 ? "success" : translateErrno(result.rawStatus)
        )

        if result.exitCode == 0 {
            let verifyData = try? Data(contentsOf: URL(fileURLWithPath: targetPath))
            if let verifyData, verifyData.count == data.count {
                logger.info("Privileged write succeeded: \(targetPath)")
                return PrivilegedWriteResult(
                    success: true, outputPath: targetPath,
                    sha256Hash: verifyData.sha256Hash, errorMessage: nil,
                    diagnostics: diags
                )
            } else {
                let msg = "Write succeeded but verification failed (file size mismatch or unreadable)"
                logger.warning(msg)
                return PrivilegedWriteResult(
                    success: false, outputPath: targetPath, sha256Hash: nil,
                    errorMessage: msg, diagnostics: diags
                )
            }
        } else {
            let msg = "Shell command failed (exit \(result.exitCode), errno \(result.rawStatus): \(translateErrno(result.rawStatus))): \(result.stderr)"
            logger.error(msg)
            return PrivilegedWriteResult(
                success: false, outputPath: targetPath, sha256Hash: nil,
                errorMessage: msg, diagnostics: diags
            )
        }
    }

    static func readFile(
        from source: URL,
        logger: IconForgeLogger = .shared
    ) throws -> PrivilegedReadResult {
        let sourcePath = source.path
        let shell = findShell() ?? "/bin/sh"

        let result = executeShellScript(
            commands: ["cat \"\(sourcePath)\""],
            logger: logger
        )

        let diags = PrivilegedDiagnostics(
            uid: getuid(), gid: getgid(), effectiveUID: geteuid(),
            shellPath: shell, shellExists: true, shellExecutable: true,
            setuidAttempted: true, setuidSucceeded: getuid() == 0,
            errnoValue: result.rawStatus,
            errnoMessage: result.rawStatus == 0 ? "success" : translateErrno(result.rawStatus)
        )

        if result.exitCode == 0, let outputData = result.stdoutData {
            return PrivilegedReadResult(success: true, data: outputData, errorMessage: nil, diagnostics: diags)
        } else {
            return PrivilegedReadResult(
                success: false, data: nil,
                errorMessage: "Read failed (exit \(result.exitCode), errno \(result.rawStatus): \(translateErrno(result.rawStatus))): \(result.stderr)",
                diagnostics: diags
            )
        }
    }

    static func fileExists(at path: String, logger: IconForgeLogger = .shared) -> Bool {
        if FileManager.default.fileExists(atPath: path) { return true }
        let result = executeShellScript(
            commands: ["test -f \"\(path)\" && echo EXISTS || echo MISSING"],
            logger: logger
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "EXISTS"
    }

    static func removeFile(at path: String, logger: IconForgeLogger = .shared) -> Bool {
        let result = executeShellScript(
            commands: ["rm -f \"\(path)\" 2>/dev/null && echo OK || echo FAIL"],
            logger: logger
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    static func removeDirectory(at path: String, logger: IconForgeLogger = .shared) -> Bool {
        let result = executeShellScript(
            commands: ["rm -rf \"\(path)\" 2>/dev/null && echo OK || echo FAIL"],
            logger: logger
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    static func sha256(of path: String, logger: IconForgeLogger = .shared) -> String? {
        let result = executeShellScript(
            commands: [
                "if command -v shasum >/dev/null 2>&1; then",
                "  shasum -a 256 \"\(path)\" | awk '{print $1}'",
                "elif command -v sha256sum >/dev/null 2>&1; then",
                "  sha256sum \"\(path)\" | awk '{print $1}'",
                "else",
                "  dd if=\"\(path)\" bs=1M 2>/dev/null | shasum -a 256 | awk '{print $1}'",
                "fi"
            ],
            logger: logger
        )
        let hash = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return hash.isEmpty ? nil : hash
    }

    static func moveFile(from source: String, to destination: String, logger: IconForgeLogger = .shared) -> Bool {
        let destDir = (destination as NSString).deletingLastPathComponent
        let result = executeShellScript(
            commands: [
                "mkdir -p \"\(destDir)\"",
                "mv \"\(source)\" \"\(destination)\" 2>/dev/null && echo OK || echo FAIL"
            ],
            logger: logger
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    static func diagnose() -> String {
        var lines: [String] = []
        lines.append("=== PrivilegedHelper Diagnostics ===")
        lines.append("UID: \(getuid()), EUID: \(geteuid()), GID: \(getgid())")
        lines.append("getuid() == 0: \(getuid() == 0)")
        for path in shellPaths {
            let exists = access(path, F_OK) == 0
            let executable = access(path, X_OK) == 0
            lines.append("Shell \(path): exists=\(exists), executable=\(executable)")
        }
        lines.append("Cached shell: \(cachedShell ?? "none")")
        let testResult = executeShellScript(commands: ["echo SHELL_OK"], logger: .shared)
        lines.append("Test shell execution: exit=\(testResult.exitCode), stdout=\(testResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        if testResult.rawStatus != 0 {
            lines.append("errno from test: \(testResult.rawStatus) (\(translateErrno(testResult.rawStatus)))")
        }
        return lines.joined(separator: "\n")
    }

    private static func executeShellScript(
        commands: [String],
        logger: IconForgeLogger
    ) -> (stdout: String, stderr: String, exitCode: Int32, rawStatus: Int32, stdoutData: Data?) {
        guard let shell = findShell() else {
            return ("", "No shell found at any path: \(shellPaths.joined(separator: ", "))", -1, -1, nil)
        }

        let script = commands.joined(separator: "\n")
        let scriptData = script.data(using: .utf8)!

        let tempDir = StorageManager.tempDirectory()
        let scriptURL = tempDir.appendingPathComponent("script_\(UUID().uuidString).sh")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? scriptData.write(to: scriptURL)
        setFilePermissions(scriptURL.path, 0o755)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        var stdoutPipeFds: [Int32] = [0, 0]
        var stderrPipeFds: [Int32] = [0, 0]
        pipe(&stdoutPipeFds)
        pipe(&stderrPipeFds)

        let scriptPath = scriptURL.path
        var argv: [UnsafeMutablePointer<CChar>?] = [
            strdup(shell), strdup(scriptPath), nil
        ]

        var pid: pid_t = 0
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipeFds[0])
        posix_spawn_file_actions_adddup2(&fileActions, stdoutPipeFds[1], STDOUT_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipeFds[1])
        posix_spawn_file_actions_addclose(&fileActions, stderrPipeFds[0])
        posix_spawn_file_actions_adddup2(&fileActions, stderrPipeFds[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, stderrPipeFds[1])

        let rawStatus = posix_spawn(&pid, shell, &fileActions, nil, argv, nil)
        posix_spawn_file_actions_destroy(&fileActions)
        for ptr in argv { ptr?.deallocate() }

        close(stdoutPipeFds[1])
        close(stderrPipeFds[1])

        guard rawStatus == 0 else {
            let errnoMsg = translateErrno(rawStatus)
            close(stdoutPipeFds[0])
            close(stderrPipeFds[0])
            return ("", "posix_spawn failed: \(rawStatus) (\(errnoMsg)) [shell=\(shell), script=\(scriptPath)]", rawStatus, rawStatus, nil)
        }

        var stdoutData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while read(stdoutPipeFds[0], &buffer, buffer.count) > 0 {
            stdoutData.append(buffer, count: buffer.count)
        }

        var stderrData = Data()
        while read(stderrPipeFds[0], &buffer, buffer.count) > 0 {
            stderrData.append(buffer, count: buffer.count)
        }

        close(stdoutPipeFds[0])
        close(stderrPipeFds[0])

        var exitCode: Int32 = 0
        waitpid(pid, &exitCode, 0)

        let exitStatus = (exitCode >> 8) & 0xff
        let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdoutStr, stderrStr, exitStatus, 0, stdoutData)
    }

    private static func setFilePermissions(_ path: String, _ mode: mode_t) {
        path.withCString { cPath in
            Foundation.chmod(cPath, mode)
        }
    }

    static func translateErrno(_ err: Int32) -> String {
        switch err {
        case 0: return "Success"
        case EPERM: return "EPERM (Operation not permitted)"
        case ENOENT: return "ENOENT (No such file or directory)"
        case EACCES: return "EACCES (Permission denied)"
        case EBUSY: return "EBUSY (Resource busy)"
        case EEXIST: return "EEXIST (File exists)"
        case EINTR: return "EINTR (Interrupted system call)"
        case EINVAL: return "EINVAL (Invalid argument)"
        case EIO: return "EIO (I/O error)"
        case EISDIR: return "EISDIR (Is a directory)"
        case ENOTDIR: return "ENOTDIR (Not a directory)"
        case ENOMEM: return "ENOMEM (Out of memory)"
        case ENOSPC: return "ENOSPC (No space left on device)"
        case ENOTEMPTY: return "ENOTEMPTY (Directory not empty)"
        case EROFS: return "EROFS (Read-only file system)"
        case ETXTBSY: return "ETXTBSY (Text file busy)"
        default: return "Unknown error (\(err))"
        }
    }
}

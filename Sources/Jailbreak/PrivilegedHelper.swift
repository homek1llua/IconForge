import Foundation

struct PrivilegedWriteResult: Sendable {
    let success: Bool
    let outputPath: String
    let sha256Hash: String?
    let errorMessage: String?
}

struct PrivilegedReadResult: Sendable {
    let success: Bool
    let data: Data?
    let errorMessage: String?
}

enum PrivilegedHelper {

    private static let shellPaths = [
        "/bin/sh",
        "/usr/bin/sh",
        "/var/jb/bin/sh",
    ]

    private static func findShell() -> String? {
        for path in shellPaths {
            if access(path, X_OK) == 0 { return path }
        }
        return nil
    }

    static func writeFile(
        data: Data,
        to destination: URL,
        backupOriginal: Bool = true,
        logger: IconForgeLogger = .shared
    ) throws -> PrivilegedWriteResult {
        let fm = FileManager.default

        let tempDir = StorageManager.tempDirectory()
        let tempFile = tempDir.appendingPathComponent("iconforge_write_\(UUID().uuidString).png")
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try data.write(to: tempFile)

        let targetDir = destination.deletingLastPathComponent().path
        let targetPath = destination.path
        let tempPath = tempFile.path

        var commands: [String] = []
        commands.append("mkdir -p \"\(targetDir)\"")

        if backupOriginal && fm.fileExists(atPath: targetPath) {
            let backupPath = "\(targetPath).iconforge_bak_\(UUID().uuidString)"
            commands.append("cp \"\(targetPath)\" \"\(backupPath)\" 2>/dev/null || true")
        }

        commands.append("rm -f \"\(targetPath)\" 2>/dev/null || true")
        commands.append("cp \"\(tempPath)\" \"\(targetPath)\"")
        commands.append("chmod 644 \"\(targetPath)\"")

        let result = executeShellScript(commands: commands, logger: logger)

        try? fm.removeItem(at: tempFile)

        if result.exitCode == 0 {
            let verifyData = try? Data(contentsOf: URL(fileURLWithPath: targetPath))
            if let verifyData, verifyData.count == data.count {
                logger.info("Privileged write succeeded: \(targetPath)")
                return PrivilegedWriteResult(
                    success: true,
                    outputPath: targetPath,
                    sha256Hash: verifyData.sha256Hash,
                    errorMessage: nil
                )
            } else {
                logger.warning("Privileged write completed but verification failed for \(targetPath)")
                return PrivilegedWriteResult(
                    success: false,
                    outputPath: targetPath,
                    sha256Hash: nil,
                    errorMessage: "Write command succeeded but verification failed"
                )
            }
        } else {
            let msg = "Shell command failed (exit \(result.exitCode)): \(result.stderr)"
            logger.error(msg)
            return PrivilegedWriteResult(
                success: false,
                outputPath: targetPath,
                sha256Hash: nil,
                errorMessage: msg
            )
        }
    }

    static func readFile(
        from source: URL,
        logger: IconForgeLogger = .shared
    ) throws -> PrivilegedReadResult {
        let sourcePath = source.path

        let result = executeShellScript(
            commands: ["cat \"\(sourcePath)\""],
            logger: logger
        )

        if result.exitCode == 0, let outputData = result.stdoutData {
            return PrivilegedReadResult(success: true, data: outputData, errorMessage: nil)
        } else {
            return PrivilegedReadResult(
                success: false,
                data: nil,
                errorMessage: "Read failed (exit \(result.exitCode)): \(result.stderr)"
            )
        }
    }

    static func fileExists(
        at path: String,
        logger: IconForgeLogger = .shared
    ) -> Bool {
        let result = executeShellScript(
            commands: ["test -f \"\(path)\" && echo EXISTS || echo MISSING"],
            logger: logger
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "EXISTS"
    }

    static func removeFile(
        at path: String,
        logger: IconForgeLogger = .shared
    ) -> Bool {
        let result = executeShellScript(
            commands: ["rm -f \"\(path)\" 2>/dev/null && echo OK || echo FAIL"],
            logger: logger
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    static func removeDirectory(
        at path: String,
        logger: IconForgeLogger = .shared
    ) -> Bool {
        let result = executeShellScript(
            commands: ["rm -rf \"\(path)\" 2>/dev/null && echo OK || echo FAIL"],
            logger: logger
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    static func sha256(
        of path: String,
        logger: IconForgeLogger = .shared
    ) -> String? {
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

    static func moveFile(
        from source: String,
        to destination: String,
        logger: IconForgeLogger = .shared
    ) -> Bool {
        let result = executeShellScript(
            commands: [
                "mkdir -p \"\((destination as NSString).deletingLastPathComponent)\"",
                "mv \"\(source)\" \"\(destination)\" 2>/dev/null && echo OK || echo FAIL"
            ],
            logger: logger
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
    }

    private static func executeShellScript(
        commands: [String],
        logger: IconForgeLogger
    ) -> (stdout: String, stderr: String, exitCode: Int32, stdoutData: Data?) {
        guard let shell = findShell() else {
            return ("", "No shell found", -1, nil)
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

        let status = posix_spawn(&pid, shell, &fileActions, nil, argv, nil)
        posix_spawn_file_actions_destroy(&fileActions)

        for ptr in argv { ptr?.deallocate() }

        close(stdoutPipeFds[1])
        close(stderrPipeFds[1])

        guard status == 0 else {
            close(stdoutPipeFds[0])
            close(stderrPipeFds[0])
            return ("", "posix_spawn failed: \(status)", status, nil)
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

        return (stdoutStr, stderrStr, exitStatus, stdoutData)
    }

    private static func setFilePermissions(_ path: String, _ mode: mode_t) {
        path.withCString { cPath in
            Foundation.chmod(cPath, mode)
        }
    }
}

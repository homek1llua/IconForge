import Foundation

final class RootFilesystem: Sendable {

    private let paths: JailbreakPaths

    init(paths: JailbreakPaths = .detect()) {
        self.paths = paths
    }

    func readFile(at url: URL) throws -> Data {
        if let data = FileManager.default.contents(atPath: url.path) {
            return data
        }

        let result = try? PrivilegedHelper.readFile(from: url)
        if let result, result.success, let data = result.data {
            return data
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RootFilesystemError.fileNotFound(url)
        }
        throw RootFilesystemError.readFailed(url)
    }

    func writeFile(_ data: Data, to url: URL, createIntermediateDirectories: Bool = true) throws {
        let fm = FileManager.default

        if createIntermediateDirectories {
            let dir = url.deletingLastPathComponent()
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }

        do {
            try data.write(to: url)
            return
        } catch {
            // Sandbox write failed, use privileged helper
        }

        let result = try PrivilegedHelper.writeFile(
            data: data,
            to: url,
            backupOriginal: false
        )

        guard result.success else {
            throw RootFilesystemError.writeFailed(url)
        }
    }

    func writeFilePrivileged(_ data: Data, to url: URL) throws {
        let result = try PrivilegedHelper.writeFile(
            data: data,
            to: url,
            backupOriginal: true
        )
        guard result.success else {
            throw RootFilesystemError.writeFailed(url)
        }
    }

    func copyItem(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let destDir = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: destDir.path) {
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: destination)
        }
        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            let ok = PrivilegedHelper.moveFile(from: source.path, to: destination.path)
            if !ok { throw error }
        }
    }

    func moveItem(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let destDir = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: destDir.path) {
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: destination)
        }
        do {
            try fm.moveItem(at: source, to: destination)
        } catch {
            let ok = PrivilegedHelper.moveFile(from: source.path, to: destination.path)
            if !ok { throw error }
        }
    }

    func removeItem(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                PrivilegedHelper.removeFile(at: url.path)
            }
        }
    }

    func removeItemPrivileged(at url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            PrivilegedHelper.removeFile(at: url.path)
        } else {
            PrivilegedHelper.removeFile(at: url.path)
        }
    }

    func removeDirectoryPrivileged(at url: URL) {
        PrivilegedHelper.removeDirectory(at: url.path)
    }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool = true) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: withIntermediateDirectories
        )
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )
    }

    func fileExists(at url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) { return true }
        return PrivilegedHelper.fileExists(at: url.path)
    }

    func fileAttributes(at url: URL) throws -> [FileAttributeKey: Any] {
        try FileManager.default.attributesOfItem(atPath: url.path)
    }

    func sha256Hash(of url: URL) throws -> String {
        if let data = FileManager.default.contents(atPath: url.path) {
            return data.sha256Hash
        }
        if let hash = PrivilegedHelper.sha256(of: url.path) {
            return hash
        }
        throw RootFilesystemError.readFailed(url)
    }

    func verifyWrite(data: Data, at url: URL) -> Bool {
        if let fileData = FileManager.default.contents(atPath: url.path) {
            return fileData.sha256Hash == data.sha256Hash
        }
        return false
    }
}

enum RootFilesystemError: Error, LocalizedError {
    case fileNotFound(URL)
    case readFailed(URL)
    case writeFailed(URL)
    case permissionDenied(URL)
    case atomicWriteFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url): return "File not found: \(url.lastPathComponent)"
        case .readFailed(let url): return "Failed to read: \(url.lastPathComponent)"
        case .writeFailed(let url): return "Failed to write: \(url.lastPathComponent)"
        case .permissionDenied(let url): return "Permission denied: \(url.lastPathComponent)"
        case .atomicWriteFailed(let url, let error): return "Atomic write failed for \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

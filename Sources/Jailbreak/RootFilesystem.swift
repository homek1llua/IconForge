import Foundation

final class RootFilesystem: Sendable {

    private let paths: JailbreakPaths

    init(paths: JailbreakPaths = .detect()) {
        self.paths = paths
    }

    func readFile(at url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RootFilesystemError.fileNotFound(url)
        }
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw RootFilesystemError.readFailed(url)
        }
        return data
    }

    func writeFile(_ data: Data, to url: URL, createIntermediateDirectories: Bool = true) throws {
        let fm = FileManager.default
        if createIntermediateDirectories {
            let dir = url.deletingLastPathComponent()
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
        let tempURL = URL(fileURLWithPath: "\(url.path).iconforge_temp_\(UUID().uuidString)")
        do {
            try data.write(to: tempURL)
        } catch {
            throw RootFilesystemError.writeFailed(tempURL)
        }
        if fm.fileExists(atPath: url.path) {
            let backupURL = URL(fileURLWithPath: "\(url.path).iconforge_bak_\(UUID().uuidString)")
            try? fm.copyItem(at: url, to: backupURL)
            try fm.removeItem(at: url)
        }
        try fm.moveItem(at: tempURL, to: url)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: url.path
        )
    }

    func copyItem(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let destDir = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: destDir.path) {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
    }

    func moveItem(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let destDir = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: destDir.path) {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: source, to: destination)
    }

    func removeItem(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
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
        FileManager.default.fileExists(atPath: url.path)
    }

    func fileAttributes(at url: URL) throws -> [FileAttributeKey: Any] {
        try FileManager.default.attributesOfItem(atPath: url.path)
    }

    func sha256Hash(of url: URL) throws -> String {
        let data = try readFile(at: url)
        return data.sha256Hash
    }

    func copyWithAtomicReplacement(source: URL, destination: URL) throws {
        let tempDest = URL(fileURLWithPath: "\(destination.path).atomic_\(UUID().uuidString)")
        try copyItem(from: source, to: tempDest)
        if fileExists(at: destination) {
            try removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempDest, to: destination)
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

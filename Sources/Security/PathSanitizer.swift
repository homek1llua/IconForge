import Foundation

struct PathSanitizer {
    
    private static let dangerousPatterns: [String] = [
        "..", "~", "/etc/passwd", "/etc/shadow", "/private/var",
        "/System/Library/LaunchDaemons", "/usr/bin/login",
        "/Applications/", "/Developer"
    ]
    
    private static let allowedBundleIdentifierPattern = "^[a-zA-Z0-9._-]+$"
    
    static func sanitizeBundleIdentifier(_ input: String) -> String? {
        guard !input.isEmpty, input.count <= 255 else { return nil }
        let pattern = allowedBundleIdentifierPattern
        guard input.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let components = input.split(separator: ".")
        guard components.count >= 2 else { return nil }
        for component in components {
            guard !component.isEmpty else { return nil }
        }
        return input
    }
    
    static func sanitizeArchivePath(_ path: String) -> String? {
        let normalized = (path as NSString).standardizingPath
        guard !normalized.hasPrefix("/") else { return nil }
        guard !normalized.contains("..") else { return nil }
        guard !normalized.contains("~") else { return nil }
        let components = normalized.split(separator: "/")
        for component in components {
            guard !component.isEmpty else { return nil }
        }
        return normalized
    }
    
    static func isPathSafe(_ path: String, withinAllowedRoots roots: [String]) -> Bool {
        let normalized = URL(fileURLWithPath: path).standardized.path
        guard !normalized.contains("..") else { return false }
        for root in roots {
            if normalized.hasPrefix(root) { return true }
        }
        return false
    }
    
    static func validateURL(_ url: URL, allowedExtensions: Set<String>) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else { return false }
        let filename = url.lastPathComponent
        guard !filename.hasPrefix(".") else { return false }
        guard !filename.contains("..") else { return false }
        return true
    }
    
    static func temporaryDirectory(for purpose: String) -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("iconforge/\(purpose)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    static func cleanTemporaryFiles(for purpose: String) {
        let dir = temporaryDirectory(for: purpose)
        try? FileManager.default.removeItem(at: dir)
    }
    
    static func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:)")
        let sanitized = name.components(separatedBy: invalid).joined()
        let trimmed = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return trimmed.isEmpty ? "unnamed" : trimmed
    }
}

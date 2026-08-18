import Foundation

struct InstalledApp: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let displayName: String
    let bundlePath: URL
    let iconPath: URL?
    let isSystemApp: Bool
    let isUserApp: Bool
    let version: String?
    let shortVersion: String?
    let containerURL: URL?
    let groupContainerURLs: [String: URL]
    let isCustomized: Bool
    let originalIconBackupPath: URL?

    var stableIdentifier: String { bundleIdentifier }

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        displayName: String,
        bundlePath: URL,
        iconPath: URL? = nil,
        isSystemApp: Bool = false,
        isUserApp: Bool = true,
        version: String? = nil,
        shortVersion: String? = nil,
        containerURL: URL? = nil,
        groupContainerURLs: [String: URL] = [:],
        isCustomized: Bool = false,
        originalIconBackupPath: URL? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.bundlePath = bundlePath
        self.iconPath = iconPath
        self.isSystemApp = isSystemApp
        self.isUserApp = isUserApp
        self.version = version
        self.shortVersion = shortVersion
        self.containerURL = containerURL
        self.groupContainerURLs = groupContainerURLs
        self.isCustomized = isCustomized
        self.originalIconBackupPath = originalIconBackupPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

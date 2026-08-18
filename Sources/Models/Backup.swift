import Foundation

struct IconBackup: Codable, Identifiable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let appDisplayName: String
    let originalIconPath: String
    let backupIconFilename: String
    let originalFileHash: String
    let createdAt: Date
    let iOSVersion: String
    let jailbreakEnvironment: String
    let isSelected: Bool

    var backupDirectory: String {
        bundleIdentifier
    }

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appDisplayName: String,
        originalIconPath: String,
        backupIconFilename: String = "original-icon.png",
        originalFileHash: String,
        createdAt: Date = Date(),
        iOSVersion: String,
        jailbreakEnvironment: String,
        isSelected: Bool = false
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appDisplayName = appDisplayName
        self.originalIconPath = originalIconPath
        self.backupIconFilename = backupIconFilename
        self.originalFileHash = originalFileHash
        self.createdAt = createdAt
        self.iOSVersion = iOSVersion
        self.jailbreakEnvironment = jailbreakEnvironment
        self.isSelected = isSelected
    }
}

struct BackupMetadata: Codable, Sendable {
    let backup: IconBackup
    let files: [BackedUpFile]
    let verificationHash: String
}

struct BackedUpFile: Codable, Sendable {
    let relativePath: String
    let originalFullPath: String
    let filename: String
    let sha256Hash: String
    let fileSize: Int64
    let modificationDate: Date?
}

struct BackupOperation: Identifiable, Sendable {
    let id: UUID
    let operationNumber: Int
    let startedAt: Date
    var completedAt: Date?
    var totalApps: Int
    var successfulApps: Int
    var failedApps: Int
    var skippedApps: Int
    var failures: [BackupFailure]
    var isComplete: Bool { completedAt != nil }

    init(
        id: UUID = UUID(),
        operationNumber: Int,
        startedAt: Date = Date(),
        totalApps: Int = 0
    ) {
        self.id = id
        self.operationNumber = operationNumber
        self.startedAt = startedAt
        self.totalApps = totalApps
        self.successfulApps = 0
        self.failedApps = 0
        self.skippedApps = 0
        self.failures = []
    }

    mutating func recordSuccess() {
        successfulApps += 1
    }

    mutating func recordFailure(_ failure: BackupFailure) {
        failedApps += 1
        failures.append(failure)
    }

    mutating func complete() {
        completedAt = Date()
    }
}

struct BackupFailure: Identifiable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let reason: String
    let suggestedAction: String?

    init(bundleIdentifier: String, reason: String, suggestedAction: String? = nil) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.reason = reason
        self.suggestedAction = suggestedAction
    }
}

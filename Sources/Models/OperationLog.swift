import Foundation

struct OperationLog: Identifiable, Codable, Sendable {
    let id: UUID
    let operationNumber: Int
    let type: OperationType
    let startedAt: Date
    var completedAt: Date?
    var status: OperationStatus
    var details: [OperationDetail]
    let iOSVersion: String
    let jailbreakType: String

    enum OperationType: String, Codable, Sendable {
        case applyIcon = "Apply Icon"
        case restoreIcon = "Restore Icon"
        case applyPack = "Apply Pack"
        case createPack = "Create Pack"
        case exportPack = "Export Pack"
        case importPack = "Import Pack"
        case backupAll = "Backup All"
        case restoreAll = "Restore All"
    }

    enum OperationStatus: String, Codable, Sendable {
        case running = "Running"
        case completed = "Completed"
        case partial = "Partially Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }

    init(
        id: UUID = UUID(),
        operationNumber: Int,
        type: OperationType,
        startedAt: Date = Date(),
        status: OperationStatus = .running,
        details: [OperationDetail] = [],
        iOSVersion: String = "",
        jailbreakType: String = ""
    ) {
        self.id = id
        self.operationNumber = operationNumber
        self.type = type
        self.startedAt = startedAt
        self.status = status
        self.details = details
        self.iOSVersion = iOSVersion
        self.jailbreakType = jailbreakType
    }

    var duration: TimeInterval? {
        guard let completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }
}

struct OperationDetail: Identifiable, Codable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    let success: Bool
    let message: String?
    let timestamp: Date

    init(bundleIdentifier: String, appName: String, success: Bool, message: String? = nil) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.success = success
        self.message = message
        self.timestamp = Date()
    }
}

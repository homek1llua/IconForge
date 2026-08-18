import XCTest
@testable import IconForge

final class BackupTests: XCTestCase {
    
    func testBackupCreation() {
        let backup = IconBackup(
            bundleIdentifier: "com.test.app",
            appDisplayName: "Test App",
            originalIconPath: "/var/mobile/test.app/icon.png",
            originalFileHash: "abc123",
            iOSVersion: "18.0",
            jailbreakEnvironment: "Rootless"
        )
        
        XCTAssertEqual(backup.bundleIdentifier, "com.test.app")
        XCTAssertEqual(backup.appDisplayName, "Test App")
        XCTAssertEqual(backup.originalFileHash, "abc123")
        XCTAssertEqual(backup.backupDirectory, "com.test.app")
    }
    
    func testBackupMetadataCodable() throws {
        let backup = IconBackup(
            bundleIdentifier: "com.test.app",
            appDisplayName: "Test App",
            originalIconPath: "/path/to/icon.png",
            originalFileHash: "abc123",
            iOSVersion: "18.0",
            jailbreakEnvironment: "Rootless"
        )
        
        let file = BackedUpFile(
            relativePath: "original-icon.png",
            originalFullPath: "/path/to/icon.png",
            filename: "icon.png",
            sha256Hash: "abc123",
            fileSize: 1024,
            modificationDate: Date()
        )
        
        let metadata = BackupMetadata(
            backup: backup,
            files: [file],
            verificationHash: "abc123"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BackupMetadata.self, from: data)
        
        XCTAssertEqual(decoded.backup.bundleIdentifier, "com.test.app")
        XCTAssertEqual(decoded.files.count, 1)
        XCTAssertEqual(decoded.files[0].sha256Hash, "abc123")
        XCTAssertEqual(decoded.verificationHash, "abc123")
    }
    
    func testBackupOperationTracking() {
        var operation = BackupOperation(
            operationNumber: 1,
            totalApps: 10
        )
        
        XCTAssertEqual(operation.totalApps, 10)
        XCTAssertFalse(operation.isComplete)
        
        for _ in 0..<8 {
            operation.recordSuccess()
        }
        operation.recordFailure(BackupFailure(
            bundleIdentifier: "com.fail",
            reason: "Not found"
        ))
        operation.recordFailure(BackupFailure(
            bundleIdentifier: "com.fail2",
            reason: "Permission denied"
        ))
        
        XCTAssertEqual(operation.successfulApps, 8)
        XCTAssertEqual(operation.failedApps, 2)
        XCTAssertEqual(operation.failures.count, 2)
        
        operation.complete()
        XCTAssertTrue(operation.isComplete)
        XCTAssertNotNil(operation.completedAt)
    }
    
    func testBackupFailure() {
        let failure = BackupFailure(
            bundleIdentifier: "com.test",
            reason: "Icon not found",
            suggestedAction: "Try reinstalling"
        )
        
        XCTAssertEqual(failure.bundleIdentifier, "com.test")
        XCTAssertEqual(failure.reason, "Icon not found")
        XCTAssertEqual(failure.suggestedAction, "Try reinstalling")
    }
}

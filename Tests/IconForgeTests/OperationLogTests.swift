import XCTest
@testable import IconForge

final class OperationLogTests: XCTestCase {
    
    func testOperationLogCreation() {
        let log = OperationLog(
            operationNumber: 1,
            type: .applyIcon,
            iOSVersion: "18.0",
            jailbreakType: "Rootless"
        )
        
        XCTAssertEqual(log.operationNumber, 1)
        XCTAssertEqual(log.type, .applyIcon)
        XCTAssertEqual(log.status, .running)
        XCTAssertNil(log.completedAt)
        XCTAssertFalse(log.isComplete)
    }
    
    func testOperationLogCompletion() {
        var log = OperationLog(
            operationNumber: 2,
            type: .applyPack
        )
        
        log.details.append(OperationDetail(
            bundleIdentifier: "com.test.app",
            appName: "Test App",
            success: true
        ))
        
        log.details.append(OperationDetail(
            bundleIdentifier: "com.fail.app",
            appName: "Fail App",
            success: false,
            reason: "Icon not found"
        ))
        
        log.status = .partial
        log.completedAt = Date()
        
        XCTAssertTrue(log.isComplete)
        XCTAssertEqual(log.details.count, 2)
        XCTAssertEqual(log.details[0].success, true)
        XCTAssertEqual(log.details[1].success, false)
    }
    
    func testOperationTypeAndStatus() {
        XCTAssertEqual(OperationLog.OperationType.allCases.count, 8)
        XCTAssertEqual(OperationLog.OperationStatus.running.rawValue, "Running")
        XCTAssertEqual(OperationLog.OperationStatus.failed.rawValue, "Failed")
    }
    
    func testDiagnosticsReport() {
        var report = DiagnosticsReport()
        report.jailbreakDetected = true
        report.environment = "Rootless"
        report.errors.append("Test error")
        
        XCTAssertFalse(report.isHealthy)
        XCTAssertTrue(report.jailbreakDetected)
        XCTAssertEqual(report.errors.count, 1)
    }
    
    func testDiagnosticsReportHealthy() {
        var report = DiagnosticsReport()
        report.jailbreakDetected = true
        report.rootAccess = true
        report.iconBackend = "iOS 18 Backend"
        
        XCTAssertTrue(report.isHealthy)
    }
}

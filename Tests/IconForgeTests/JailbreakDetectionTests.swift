import XCTest
@testable import IconForge

final class JailbreakDetectionTests: XCTestCase {
    
    func testJailbreakEnvironmentValues() {
        XCTAssertEqual(JailbreakEnvironment.unsupported.rawValue, "Unsupported")
        XCTAssertEqual(JailbreakEnvironment.jailed.rawValue, "Jailed")
        XCTAssertEqual(JailbreakEnvironment.jailbroken.rawValue, "Jailbroken")
        XCTAssertEqual(JailbreakEnvironment.jailbrokenRootless.rawValue, "Rootless")
        XCTAssertEqual(JailbreakEnvironment.jailbrokenRootful.rawValue, "Rootful")
    }
    
    func testJailbreakTypeValues() {
        XCTAssertEqual(JailbreakType.unc0ver.rawValue, "unc0ver")
        XCTAssertEqual(JailbreakType.checkra1n.rawValue, "checkra1n")
        XCTAssertEqual(JailbreakType.dopamine.rawValue, "Dopamine")
        XCTAssertEqual(JailbreakType.palera1n.rawValue, "palera1n")
        XCTAssertEqual(JailbreakType.none.rawValue, "None")
    }
    
    func testRequiredCapabilityAllCases() {
        XCTAssertEqual(RequiredCapability.allCases.count, 7)
    }
    
    func testJailbreakDetectorSingleton() {
        let detector1 = JailbreakDetector.shared
        let detector2 = JailbreakDetector.shared
        XCTAssertTrue(detector1 === detector2)
    }
    
    func testJailbreakPathsDetect() {
        let paths = JailbreakPaths.detect()
        XCTAssertNotNil(paths.rootPrefix)
        XCTAssertNotNil(paths.systemLibrary)
        XCTAssertNotNil(paths.varMobile)
    }
    
    func testRespringMethodDescriptions() {
        for method in RespringMethod.allCases {
            XCTAssertFalse(method.description.isEmpty)
            XCTAssertFalse(method.rawValue.isEmpty)
        }
    }
    
    func testRespringMethodDestructiveFlag() {
        XCTAssertFalse(RespringMethod.refreshIcons.isDestructive)
        XCTAssertTrue(RespringMethod.fullRespring.isDestructive)
        XCTAssertTrue(RespringMethod.restartSpringBoard.isDestructive)
    }
    
    func testRespringManager() {
        let manager = RespringManager()
        let methods = manager.availableRespringMethods()
        XCTAssertFalse(methods.isEmpty)
    }
}

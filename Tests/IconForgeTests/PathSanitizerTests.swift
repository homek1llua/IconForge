import XCTest
@testable import IconForge

final class PathSanitizerTests: XCTestCase {
    
    func testValidBundleIdentifier() {
        XCTAssertNotNil(PathSanitizer.sanitizeBundleIdentifier("com.google.ios.youtube"))
        XCTAssertNotNil(PathSanitizer.sanitizeBundleIdentifier("com.apple.mobilesafari"))
        XCTAssertNotNil(PathSanitizer.sanitizeBundleIdentifier("com.spotify.client"))
        XCTAssertNotNil(PathSanitizer.sanitizeBundleIdentifier("org.x.xamarin.ios"))
        XCTAssertNotNil(PathSanitizer.sanitizeBundleIdentifier("com.example-app.test123"))
    }
    
    func testInvalidBundleIdentifier() {
        XCTAssertNil(PathSanitizer.sanitizeBundleIdentifier(""))
        XCTAssertNil(PathSanitizer.sanitizeBundleIdentifier("com"))
        XCTAssertNil(PathSanitizer.sanitizeBundleIdentifier("justaword"))
        XCTAssertNil(PathSanitizer.sanitizeBundleIdentifier("com../etc/passwd"))
        XCTAssertNil(PathSanitizer.sanitizeBundleIdentifier("com.app; rm -rf /"))
        XCTAssertNil(PathSanitizer.sanitizeBundleIdentifier(String(repeating: "a", count: 256)))
    }
    
    func testSafeArchivePaths() {
        XCTAssertNotNil(PathSanitizer.sanitizeArchivePath("icons/com.app.png"))
        XCTAssertNotNil(PathSanitizer.sanitizeArchivePath("metadata/com.app.json"))
        XCTAssertNotNil(PathSanitizer.sanitizeArchivePath("cover.png"))
        XCTAssertNil(PathSanitizer.sanitizeArchivePath("/etc/passwd"))
        XCTAssertNil(PathSanitizer.sanitizeArchivePath("../../../etc/passwd"))
        XCTAssertNil(PathSanitizer.sanitizeArchivePath("~/secret"))
    }
    
    func testPathSafety() {
        XCTAssertTrue(PathSanitizer.isPathSafe(
            "/var/mobile/Containers/Bundle/Application/test.app/icon.png",
            withinRoots: ["/var/mobile"]
        ))
        XCTAssertFalse(PathSanitizer.isPathSafe(
            "/etc/passwd",
            withinRoots: ["/var/mobile"]
        ))
        XCTAssertFalse(PathSanitizer.isPathSafe(
            "/var/mobile/../../../etc/passwd",
            withinRoots: ["/var/mobile"]
        ))
    }
    
    func testURLValidation() {
        let allowed: Set<String> = ["png", "jpg", "jpeg"]
        XCTAssertTrue(PathSanitizer.validateURL(
            URL(fileURLWithPath: "/tmp/icon.png"),
            allowedExtensions: allowed
        ))
        XCTAssertTrue(PathSanitizer.validateURL(
            URL(fileURLWithPath: "/tmp/photo.jpg"),
            allowedExtensions: allowed
        ))
        XCTAssertFalse(PathSanitizer.validateURL(
            URL(fileURLWithPath: "/tmp/script.swift"),
            allowedExtensions: allowed
        ))
    }
    
    func testFilenameSanitization() {
        let sanitized = PathSanitizer.sanitizeFilename("My Pack<>:\"/\\|?*Name")
        XCTAssertFalse(sanitized.contains("<"))
        XCTAssertFalse(sanitized.contains(">"))
        XCTAssertFalse(sanitized.contains(":"))
        XCTAssertFalse(sanitized.contains("/"))
        XCTAssertFalse(sanitized.isEmpty)
        
        let empty = PathSanitizer.sanitizeFilename("   . . ")
        XCTAssertEqual(empty, "unnamed")
    }
}

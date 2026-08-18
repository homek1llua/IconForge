import XCTest
@testable import IconForge

final class HashVerificationTests: XCTestCase {
    
    func testDataHashing() {
        let data1 = "hello world".data(using: .utf8)!
        let data2 = "hello world".data(using: .utf8)!
        let data3 = "hello world!".data(using: .utf8)!
        
        XCTAssertEqual(data1.sha256Hash, data2.sha256Hash)
        XCTAssertNotEqual(data1.sha256Hash, data3.sha256Hash)
    }
    
    func testEmptyDataHash() {
        let empty = Data()
        let hash = empty.sha256Hash
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64)
    }
    
    func testHashConsistency() {
        let data = "iconforge_test_data".data(using: .utf8)!
        let hash1 = data.sha256Hash
        let hash2 = data.sha256Hash
        XCTAssertEqual(hash1, hash2)
    }
    
    func testHashHexFormat() {
        let data = "test".data(using: .utf8)!
        let hash = data.sha256Hash
        
        let hexPattern = "^[0-9a-f]{64}$"
        XCTAssertTrue(hash.range(of: hexPattern, options: .regularExpression) != nil, "Hash should be 64 hex characters")
    }
    
    func testLargeDataHash() {
        var data = Data()
        for _ in 0..<100000 {
            data.append(contentsOf: [0x41, 0x42, 0x43])
        }
        let hash = data.sha256Hash
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64)
    }
}

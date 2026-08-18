import XCTest
@testable import IconForge

final class IconPackImportExportTests: XCTestCase {
    
    func testIconPackCreation() {
        let manager = PackManager()
        let pack = manager.createPack(
            name: "Test Pack",
            description: "A test",
            author: "Tester"
        )
        
        XCTAssertEqual(pack.name, "Test Pack")
        XCTAssertEqual(pack.description, "A test")
        XCTAssertEqual(pack.author, "Tester")
        XCTAssertEqual(pack.formatVersion, 1)
        XCTAssertTrue(pack.icons.isEmpty)
    }
    
    func testPackAddRemoveIcons() {
        var pack = IconPack(name: "Test")
        
        let entry1 = IconPackEntry(
            bundleIdentifier: "com.app1",
            filename: "com.app1.png",
            hash: "hash1"
        )
        let entry2 = IconPackEntry(
            bundleIdentifier: "com.app2",
            filename: "com.app2.png",
            hash: "hash2"
        )
        
        pack.addIcon(entry1)
        pack.addIcon(entry2)
        XCTAssertEqual(pack.iconCount, 2)
        
        pack.removeIcon(bundleIdentifier: "com.app1")
        XCTAssertEqual(pack.iconCount, 1)
        XCTAssertEqual(pack.icons[0].bundleIdentifier, "com.app2")
    }
    
    func testPackRename() {
        var pack = IconPack(name: "Old Name")
        let before = pack.modifiedAt
        pack.rename(to: "New Name")
        XCTAssertEqual(pack.name, "New Name")
        XCTAssertGreaterThanOrEqual(pack.modifiedAt, before)
    }
    
    func testPackDeduplication() {
        var pack = IconPack(name: "Test")
        
        let entry1 = IconPackEntry(
            bundleIdentifier: "com.app1",
            filename: "com.app1.png",
            hash: "hash1"
        )
        let entry1Updated = IconPackEntry(
            bundleIdentifier: "com.app1",
            filename: "com.app1_v2.png",
            hash: "hash1v2"
        )
        
        pack.addIcon(entry1)
        XCTAssertEqual(pack.iconCount, 1)
        
        pack.addIcon(entry1Updated)
        XCTAssertEqual(pack.iconCount, 1)
        XCTAssertEqual(pack.icons[0].hash, "hash1v2")
    }
    
    func testPackDictionary() {
        var pack = IconPack(name: "Dict Test")
        
        pack.addIcon(IconPackEntry(
            bundleIdentifier: "com.a",
            filename: "a.png",
            hash: "ha"
        ))
        pack.addIcon(IconPackEntry(
            bundleIdentifier: "com.b",
            filename: "b.png",
            hash: "hb"
        ))
        
        let dictionary = Dictionary(pack.icons.map { ($0.bundleIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(dictionary.count, 2)
        XCTAssertNotNil(dictionary["com.a"])
        XCTAssertNotNil(dictionary["com.b"])
    }
    
    func testIconValidation() {
        let validData = UIImage.generateTestImageData()
        XCTAssertNotNil(validData)
        
        if let data = validData {
            let result = IconValidator.validateImageData(data)
            XCTAssertTrue(result.isValid)
        }
    }
    
    func testIconValidationEmptyData() {
        let result = IconValidator.validateImageData(Data())
        XCTAssertFalse(result.isValid)
    }
    
    func testIconValidationTooLarge() {
        var data = Data(count: 20 * 1024 * 1024)
        data[0] = 0x89
        data[1] = 0x50
        data[2] = 0x4E
        data[3] = 0x47
        let result = IconValidator.validateImageData(data)
        XCTAssertFalse(result.isValid)
    }
}

extension UIImage {
    static func generateTestImageData() -> Data? {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()
    }
}

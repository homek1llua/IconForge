import XCTest
@testable import IconForge

final class ManifestTests: XCTestCase {
    
    func testManifestEncoding() throws {
        let pack = IconPack(
            name: "Test Pack",
            description: "A test pack",
            author: "TestAuthor",
            icons: [
                IconPackEntry(
                    bundleIdentifier: "com.example.app",
                    filename: "com.example.app.png",
                    hash: "abc123def456"
                )
            ]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(pack)
        
        XCTAssertFalse(data.isEmpty)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("Test Pack"))
        XCTAssertTrue(json.contains("com.example.app"))
        XCTAssertTrue(json.contains("formatVersion"))
    }
    
    func testManifestDecoding() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Midnight",
            "description": "Dark custom icons",
            "author": null,
            "createdAt": "2026-08-18T00:00:00Z",
            "modifiedAt": "2026-08-18T00:00:00Z",
            "icons": [
                {
                    "id": "00000000-0000-0000-0000-000000000002",
                    "bundleIdentifier": "com.google.ios.youtube",
                    "filename": "com.google.ios.youtube.png",
                    "hash": "abc123",
                    "addedAt": "2026-08-18T00:00:00Z",
                    "metadata": null
                }
            ],
            "coverImageFilename": null,
            "formatVersion": 1
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let pack = try decoder.decode(IconPack.self, from: data)
        
        XCTAssertEqual(pack.name, "Midnight")
        XCTAssertEqual(pack.description, "Dark custom icons")
        XCTAssertEqual(pack.icons.count, 1)
        XCTAssertEqual(pack.icons[0].bundleIdentifier, "com.google.ios.youtube")
        XCTAssertEqual(pack.formatVersion, 1)
    }
    
    func testManifestRoundTrip() throws {
        let pack = IconPack(
            name: "Round Trip",
            description: "Test round trip",
            icons: [
                IconPackEntry(
                    bundleIdentifier: "com.test.app1",
                    filename: "com.test.app1.png",
                    hash: "hash1"
                ),
                IconPackEntry(
                    bundleIdentifier: "com.test.app2",
                    filename: "com.test.app2.png",
                    hash: "hash2"
                )
            ]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(pack)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(IconPack.self, from: encoded)
        
        XCTAssertEqual(pack.name, decoded.name)
        XCTAssertEqual(pack.icons.count, decoded.icons.count)
        XCTAssertEqual(pack.icons[0].bundleIdentifier, decoded.icons[0].bundleIdentifier)
        XCTAssertEqual(pack.icons[1].hash, decoded.icons[1].hash)
    }
    
    func testIconPackEntryCodable() throws {
        let entry = IconPackEntry(
            bundleIdentifier: "com.example.test",
            filename: "icon.png",
            hash: "abcdef123456",
            metadata: IconMetadata(
                cornerRadius: 22.37,
                shapePreset: "iOS Default"
            )
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(IconPackEntry.self, from: data)
        
        XCTAssertEqual(entry.bundleIdentifier, decoded.bundleIdentifier)
        XCTAssertEqual(entry.filename, decoded.filename)
        XCTAssertEqual(entry.hash, decoded.hash)
        XCTAssertEqual(entry.metadata?.cornerRadius, 22.37)
    }
    
    func testEmptyManifest() throws {
        let pack = IconPack(name: "Empty Pack")
        XCTAssertEqual(pack.iconCount, 0)
        XCTAssertTrue(pack.icons.isEmpty)
    }
}

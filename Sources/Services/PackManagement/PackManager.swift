import Foundation
import UIKit

final class PackManager: @unchecked Sendable {
    
    private let filesystem: RootFilesystem
    private let logger: IconForgeLogger
    
    init(
        filesystem: RootFilesystem = RootFilesystem(),
        logger: IconForgeLogger = .shared
    ) {
        self.filesystem = filesystem
        self.logger = logger
    }
    
    func createPack(
        name: String,
        description: String = "",
        author: String? = nil,
        icons: [(bundleIdentifier: String, imageData: Data, metadata: IconMetadata?)] = []
    ) -> IconPack {
        var pack = IconPack(name: name, description: description, author: author)
        for icon in icons {
            let hash = icon.imageData.sha256Hash
            let filename = "\(PathSanitizer.sanitizeFilename(icon.bundleIdentifier)).png"
            let entry = IconPackEntry(
                bundleIdentifier: icon.bundleIdentifier,
                filename: filename,
                hash: hash,
                metadata: icon.metadata
            )
            pack.addIcon(entry)
        }
        return pack
    }
    
    func exportPack(_ pack: IconPack, iconDataMap: [String: Data], coverImage: UIImage? = nil) async throws -> URL {
        let tempDir = StorageManager.tempDirectory().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let iconsDir = tempDir.appendingPathComponent("icons")
        let metadataDir = tempDir.appendingPathComponent("metadata")
        try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        
        for icon in pack.icons {
            if let data = iconDataMap[icon.bundleIdentifier] {
                let fileURL = iconsDir.appendingPathComponent(icon.filename)
                try data.write(to: fileURL)
            }
        }
        
        if let coverImage, let coverData = coverImage.pngData() {
            let coverURL = tempDir.appendingPathComponent("cover.png")
            try coverData.write(to: coverURL)
        }
        
        var encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(pack)
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))
        
        let zipURL = StorageManager.packsDirectory().appendingPathComponent(
            "\(PathSanitizer.sanitizeFilename(pack.name)).iconpack"
        )
        try createZipArchive(from: tempDir, to: zipURL)
        logger.info("Exported icon pack '\(pack.name)' to \(zipURL.path)")
        return zipURL
    }
    
    func importPack(from url: URL) async throws -> (pack: IconPack, iconDataMap: [String: Data]) {
        let validation = IconValidator.validateIconPackArchive(at: url)
        guard validation.isValid else {
            throw IconForgeError.packImportFailed(validation.message ?? "Validation failed")
        }
        
        let tempDir = StorageManager.tempDirectory().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try extractZipArchive(from: url, to: tempDir)
        
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw IconForgeError.packManifestInvalid("manifest.json not found in archive")
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let pack = try decoder.decode(IconPack.self, from: manifestData)
        
        guard pack.formatVersion <= 1 else {
            throw IconForgeError.packManifestInvalid("Unsupported format version: \(pack.formatVersion)")
        }
        
        var iconDataMap: [String: Data] = [:]
        for entry in pack.icons {
            let sanitizedPath = PathSanitizer.sanitizeArchivePath("icons/\(entry.filename)")
            guard let safePath = sanitizedPath else {
                logger.warning("Skipping entry with unsafe path: \(entry.filename)")
                continue
            }
            let fileURL = tempDir.appendingPathComponent(safePath)
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL) else {
                logger.warning("Icon file not found for \(entry.bundleIdentifier)")
                continue
            }
            let computedHash = data.sha256Hash
            if computedHash != entry.hash {
                logger.warning("Hash mismatch for \(entry.bundleIdentifier): expected \(entry.hash), got \(computedHash)")
            }
            iconDataMap[entry.bundleIdentifier] = data
        }
        
        logger.info("Imported icon pack '\(pack.name)' with \(iconDataMap.count) icons")
        return (pack, iconDataMap)
    }
    
    func savePack(_ pack: IconPack) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(pack)
        let url = StorageManager.packsDirectory().appendingPathComponent(
            "\(PathSanitizer.sanitizeFilename(pack.name)).json"
        )
        try data.write(to: url, options: .atomic)
    }
    
    func loadAllPacks() -> [IconPack] {
        let dir = StorageManager.packsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else { return [] }
        
        var packs: [IconPack] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file) else { continue }
            if let pack = try? decoder.decode(IconPack.self, from: data) {
                packs.append(pack)
            }
        }
        return packs.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    func deletePack(_ pack: IconPack) throws {
        let jsonURL = StorageManager.packsDirectory().appendingPathComponent(
            "\(PathSanitizer.sanitizeFilename(pack.name)).json"
        )
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            try FileManager.default.removeItem(at: jsonURL)
        }
        let iconpackURL = StorageManager.packsDirectory().appendingPathComponent(
            "\(PathSanitizer.sanitizeFilename(pack.name)).iconpack"
        )
        if FileManager.default.fileExists(atPath: iconpackURL.path) {
            try FileManager.default.removeItem(at: iconpackURL)
        }
    }
    
    func duplicatePack(_ pack: IconPack) -> IconPack {
        IconPack(
            id: UUID(),
            name: "\(pack.name) Copy",
            description: pack.description,
            author: pack.author,
            createdAt: Date(),
            modifiedAt: Date(),
            icons: pack.icons,
            coverImageFilename: pack.coverImageFilename,
            formatVersion: pack.formatVersion
        )
    }
    
    private func createZipArchive(from sourceDirectory: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", destination.path, "."]
        process.currentDirectoryURL = sourceDirectory
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw IconForgeError.packExportFailed("zip command failed with status \(process.terminationStatus)")
        }
    }
    
    private func extractZipArchive(from source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", source.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw IconForgeError.packImportFailed("unzip command failed with status \(process.terminationStatus)")
        }
    }
}

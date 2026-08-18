import Foundation

struct IconPack: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var author: String?
    var createdAt: Date
    var modifiedAt: Date
    var icons: [IconPackEntry]
    var coverImageFilename: String?
    var formatVersion: Int

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        author: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        icons: [IconPackEntry] = [],
        coverImageFilename: String? = nil,
        formatVersion: Int = 1
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.icons = icons
        self.coverImageFilename = coverImageFilename
        self.formatVersion = formatVersion
    }

    var iconCount: Int { icons.count }

    mutating func addIcon(_ entry: IconPackEntry) {
        icons.removeAll { $0.bundleIdentifier == entry.bundleIdentifier }
        icons.append(entry)
        modifiedAt = Date()
    }

    mutating func removeIcon(bundleIdentifier: String) {
        icons.removeAll { $0.bundleIdentifier == bundleIdentifier }
        modifiedAt = Date()
    }

    mutating func rename(to newName: String) {
        name = newName
        modifiedAt = Date()
    }
}

struct IconPackEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let filename: String
    let hash: String
    let addedAt: Date
    let metadata: IconMetadata?

    var stableIdentifier: String { bundleIdentifier }

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        filename: String,
        hash: String,
        addedAt: Date = Date(),
        metadata: IconMetadata? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.filename = filename
        self.hash = hash
        self.addedAt = addedAt
        self.metadata = metadata
    }
}

struct IconMetadata: Codable, Sendable {
    let originalIconFilename: String?
    let cornerRadius: CGFloat?
    let backgroundColor: String?
    let shapePreset: String?
    let notes: String?

    init(
        originalIconFilename: String? = nil,
        cornerRadius: CGFloat? = nil,
        backgroundColor: String? = nil,
        shapePreset: String? = nil,
        notes: String? = nil
    ) {
        self.originalIconFilename = originalIconFilename
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.shapePreset = shapePreset
        self.notes = notes
    }
}

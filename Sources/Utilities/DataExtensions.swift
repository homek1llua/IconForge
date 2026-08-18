import Foundation
import CryptoKit

extension Data {
    var sha256Hash: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    var prettyJSON: String? {
        guard let object = try? JSONSerialization.jsonObject(with: self),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted) else {
            return nil
        }
        return String(data: prettyData, encoding: .utf8)
    }
}

extension URL {
    var fileSize: Int64 {
        Int64((try? resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
    
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    
    var readableSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    func createIfNotExists() throws {
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(at: self, withIntermediateDirectories: true)
        }
    }
}

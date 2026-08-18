import Foundation
import UIKit

struct IconValidator {
    
    static let maxIconSize = CGSize(width: 1024, height: 1024)
    static let minIconSize = CGSize(width: 32, height: 32)
    static let maxFileSize: Int64 = 10 * 1024 * 1024
    static let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "bmp", "gif"]
    
    static func validateImage(_ image: UIImage) -> IconValidationResult {
        var warnings: [String] = []
        guard let size = image.cgImage?.size else {
            return .invalid("Unable to read image properties.")
        }
        if size.width < minIconSize.width || size.height < minIconSize.height {
            warnings.append("Image is smaller than recommended minimum (\(Int(minIconSize.width))x\(Int(minIconSize.height))).")
        }
        if size.width > maxIconSize.width || size.height > maxIconSize.height {
            warnings.append("Image is larger than standard icon size. It will be downscaled.")
        }
        let isSquare = abs(size.width - size.height) < 1.0
        if !isSquare {
            warnings.append("Image is not square. It will be cropped to a square.")
        }
        if warnings.isEmpty {
            return .valid
        }
        return .validWithWarnings(warnings)
    }
    
    static func validateImageData(_ data: Data) -> IconValidationResult {
        if data.count > maxFileSize {
            return .invalid("File is too large (\(data.count / 1024 / 1024)MB). Maximum is \(maxFileSize / 1024 / 1024)MB.")
        }
        if data.count < 100 {
            return .invalid("File is too small to be a valid image.")
        }
        guard UIImage(data: data) != nil else {
            return .invalid("Unable to decode image data. The file may be corrupted.")
        }
        return .valid
    }
    
    static func validateIconFile(at url: URL) -> IconValidationResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return .invalid("File does not exist.")
        }
        guard fm.isReadableFile(atPath: url.path) else {
            return .invalid("File is not readable.")
        }
        guard validateURL(url, allowedExtensions: allowedExtensions) else {
            return .invalid("File type '\(url.pathExtension)' is not supported.")
        }
        guard let data = try? Data(contentsOf: url) else {
            return .invalid("Unable to read file contents.")
        }
        return validateImageData(data)
    }
    
    static func validateIconPackArchive(at url: URL) -> IconPackValidationResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return .invalid("Archive file does not exist.")
        }
        guard url.pathExtension.lowercased() == "iconpack" else {
            return .invalid("File does not have .iconpack extension.")
        }
        guard let data = try? Data(contentsOf: url) else {
            return .invalid("Unable to read archive.")
        }
        guard data.count > 100 else {
            return .invalid("Archive is too small to be a valid icon pack.")
        }
        guard data.count < 500 * 1024 * 1024 else {
            return .invalid("Archive is too large (maximum 500MB).")
        }
        return .valid
    }
    
    private static func validateURL(_ url: URL, allowedExtensions: Set<String>) -> Bool {
        let ext = url.pathExtension.lowercased()
        return allowedExtensions.contains(ext)
    }
}

enum IconValidationResult: Sendable {
    case valid
    case validWithWarnings([String])
    case invalid(String)
    
    var isValid: Bool {
        if case .invalid = self { return false }
        return true
    }
    
    var message: String? {
        switch self {
        case .valid: return nil
        case .validWithWarnings(let warnings): return warnings.joined(separator: "\n")
        case .invalid(let msg): return msg
        }
    }
}

enum IconPackValidationResult: Sendable {
    case valid
    case validWithWarnings([String])
    case invalid(String)
    
    var isValid: Bool {
        if case .invalid = self { return false }
        return true
    }
    
    var message: String? {
        switch self {
        case .valid: return nil
        case .validWithWarnings(let warnings): return warnings.joined(separator: "\n")
        case .invalid(let msg): return msg
        }
    }
}

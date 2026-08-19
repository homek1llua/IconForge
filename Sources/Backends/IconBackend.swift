import Foundation
import UIKit

protocol IconBackend: AnyObject, Sendable {
    var name: String { get }
    var isAvailable: Bool { get }
    func readIcon(for app: InstalledApp) async throws -> UIImage
    func applyIcon(_ image: UIImage, to app: InstalledApp) async throws
    func restoreOriginalIcon(for app: InstalledApp) async throws
    func refreshIcon(for app: InstalledApp) async
    func refreshAllIcons() async
}

enum DetectedIOSVersion: Int, Comparable, CustomStringConvertible {
    case ios14 = 14
    case ios15 = 15
    case ios16 = 16
    case ios17 = 17
    case ios18 = 18

    static func < (lhs: DetectedIOSVersion, rhs: DetectedIOSVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String { "iOS \(rawValue)" }
}

final class BackendManager: @unchecked Sendable {

    static let shared = BackendManager()

    private var backends: [IconBackend] = []
    private var selectedBackend: IconBackend?
    private let filesystem: RootFilesystem
    private let paths: JailbreakPaths
    private let iconCacheManager: IconCacheManager
    private let launchServices: LaunchServicesManager
    private let logger: IconForgeLogger
    let detectedVersion: DetectedIOSVersion

    private init() {
        self.filesystem = RootFilesystem()
        self.paths = JailbreakPaths.detect()
        self.iconCacheManager = IconCacheManager()
        self.launchServices = LaunchServicesManager()
        self.logger = .shared
        self.detectedVersion = Self.detectRuntimeIOSVersion()
        registerBackends()
    }

    private func registerBackends() {
        let version = detectedVersion
        logger.info("Runtime iOS version detected: \(version) (raw: \(version.rawValue))")

        let candidate: IconBackend = {
            switch version {
            case .ios18:
                return IconBackendIOS18(
                    filesystem: filesystem, paths: paths,
                    iconCacheManager: iconCacheManager,
                    launchServices: launchServices, logger: logger
                )
            case .ios17:
                return IconBackendIOS17(
                    filesystem: filesystem, paths: paths,
                    iconCacheManager: iconCacheManager,
                    launchServices: launchServices, logger: logger
                )
            case .ios16:
                return IconBackendIOS16(
                    filesystem: filesystem, paths: paths,
                    iconCacheManager: iconCacheManager,
                    launchServices: launchServices, logger: logger
                )
            case .ios15:
                return IconBackendIOS15(
                    filesystem: filesystem, paths: paths,
                    iconCacheManager: iconCacheManager,
                    launchServices: launchServices, logger: logger
                )
            case .ios14:
                return IconBackendIOS14(
                    filesystem: filesystem, paths: paths,
                    iconCacheManager: iconCacheManager,
                    launchServices: launchServices, logger: logger
                )
            }
        }()

        if candidate.isAvailable {
            selectedBackend = candidate
            backends = [candidate]
            logger.info("Selected backend: \(candidate.name)")
        } else {
            let fallback = IconBackendIOS14(
                filesystem: filesystem, paths: paths,
                iconCacheManager: iconCacheManager,
                launchServices: launchServices, logger: logger
            )
            selectedBackend = fallback
            backends = [fallback]
            logger.warning("Version-specific backend unavailable, falling back to iOS 14 backend")
        }

        if let backend = selectedBackend {
            logger.info("Registered icon backend: \(backend.name)")
        }
    }

    func bestBackend() -> IconBackend? {
        selectedBackend
    }

    func backendName() -> String {
        selectedBackend?.name ?? "None"
    }

    func diagnostics() -> String {
        var lines: [String] = []
        lines.append("iOS Version: \(detectedVersion) (raw: \(detectedVersion.rawValue))")
        lines.append("Selected Backend: \(backendName())")
        lines.append("Backend Available: \(selectedBackend?.isAvailable ?? false)")
        lines.append(PrivilegedHelper.diagnose())
        return lines.joined(separator: "\n")
    }

    private static func detectRuntimeIOSVersion() -> DetectedIOSVersion {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let major = version.majorVersion
        switch major {
        case 18...: return .ios18
        case 17: return .ios17
        case 16: return .ios16
        case 15: return .ios15
        case 14: return .ios14
        default:
            if major > 18 { return .ios18 }
            return .ios14
        }
    }
}

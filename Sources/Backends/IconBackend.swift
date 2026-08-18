import Foundation
import UIKit

protocol IconBackend: AnyObject, Sendable {
    var name: String { get }
    var isAvailable: Bool { get }
    func readIcon(for app: InstalledApp) async throws -> UIImage
    func applyIcon(_ image: UIImage, to app: InstalledApp) async throws
    func restoreOriginalIcon(for app: InstalledApp) async throws
    func refreshIcon(for app: InstalledApp) async throws
    func refreshAllIcons() async throws
}

final class BackendManager: @unchecked Sendable {
    
    static let shared = BackendManager()
    
    private var backends: [IconBackend] = []
    private let filesystem: RootFilesystem
    private let paths: JailbreakPaths
    private let iconCacheManager: IconCacheManager
    private let launchServices: LaunchServicesManager
    private let logger: IconForgeLogger
    
    private init() {
        self.filesystem = RootFilesystem()
        self.paths = JailbreakPaths.detect()
        self.iconCacheManager = IconCacheManager()
        self.launchServices = LaunchServicesManager()
        self.logger = .shared
        registerBackends()
    }
    
    private func registerBackends() {
        let iosVersion = detectIOSVersion()
        logger.info("Detected iOS version: \(iosVersion)")
        
        if #available(iOS 18.0, *) {
            let backend = IconBackendIOS18(
                filesystem: filesystem, paths: paths,
                iconCacheManager: iconCacheManager,
                launchServices: launchServices, logger: logger
            )
            if backend.isAvailable { backends.append(backend) }
        }
        if #available(iOS 17.0, *) {
            let backend = IconBackendIOS17(
                filesystem: filesystem, paths: paths,
                iconCacheManager: iconCacheManager,
                launchServices: launchServices, logger: logger
            )
            if backend.isAvailable { backends.append(backend) }
        }
        if #available(iOS 16.0, *) {
            let backend = IconBackendIOS16(
                filesystem: filesystem, paths: paths,
                iconCacheManager: iconCacheManager,
                launchServices: launchServices, logger: logger
            )
            if backend.isAvailable { backends.append(backend) }
        }
        if #available(iOS 15.0, *) {
            let backend = IconBackendIOS15(
                filesystem: filesystem, paths: paths,
                iconCacheManager: iconCacheManager,
                launchServices: launchServices, logger: logger
            )
            if backend.isAvailable { backends.append(backend) }
        }
        let backend14 = IconBackendIOS14(
            filesystem: filesystem, paths: paths,
            iconCacheManager: iconCacheManager,
            launchServices: launchServices, logger: logger
        )
        if backend14.isAvailable { backends.append(backend14) }
        
        if backends.isEmpty {
            backends.append(backend14)
        }
        
        logger.info("Registered \(backends.count) icon backend(s): \(backends.map(\.name).joined(separator: ", "))")
    }
    
    func bestBackend() -> IconBackend? {
        backends.first { $0.isAvailable }
    }
    
    func backendName() -> String {
        bestBackend()?.name ?? "None"
    }
    
    private func detectIOSVersion() -> String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
}

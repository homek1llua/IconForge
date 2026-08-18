import SwiftUI
import UIKit

@MainActor
final class IconEditorViewModel: ObservableObject {
    @Published var originalImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var editorState = IconEditorState()
    @Published var selectedApp: InstalledApp?
    @Published var isProcessing: Bool = false
    @Published var isApplying: Bool = false
    @Published var applySuccess: Bool = false
    @Published var applyError: String?
    @Published var showSystemAppWarning: Bool = false
    @Published var pendingSystemAppConfirmation: Bool = false
    
    private let renderer = IconRenderer.shared
    private let backupManager = BackupManager()
    private let logger: IconForgeLogger = .shared
    
    var hasImage: Bool { originalImage != nil }
    var canApply: Bool { originalImage != nil && selectedApp != nil && !isProcessing && !isApplying }
    
    func loadImage(from data: Data) {
        guard let image = UIImage(data: data) else {
            logger.error("Failed to load image from data")
            return
        }
        originalImage = image
        processImage()
    }
    
    func loadImage(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            logger.error("Failed to load image from URL: \(url.path)")
            return
        }
        loadImage(from: data)
    }
    
    func setApp(_ app: InstalledApp) {
        selectedApp = app
        if app.isSystemApp {
            showSystemAppWarning = true
        }
    }
    
    func confirmSystemApp() {
        showSystemAppWarning = false
        pendingSystemAppConfirmation = true
    }
    
    func cancelSystemApp() {
        showSystemAppWarning = false
        pendingSystemAppConfirmation = false
        selectedApp = nil
    }
    
    func updateBrightness(_ value: Double) {
        editorState.brightness = value
        processImage()
    }
    
    func updateContrast(_ value: Double) {
        editorState.contrast = value
        processImage()
    }
    
    func updateSaturation(_ value: Double) {
        editorState.saturation = value
        processImage()
    }
    
    func updateExposure(_ value: Double) {
        editorState.exposure = value
        processImage()
    }
    
    func updateHue(_ value: Double) {
        editorState.hue = value
        processImage()
    }
    
    func updateSharpness(_ value: Double) {
        editorState.sharpness = value
        processImage()
    }
    
    func updateBlur(_ value: Double) {
        editorState.blur = value
        processImage()
    }
    
    func updateVignette(_ value: Double) {
        editorState.vignette = value
        processImage()
    }
    
    func toggleGrayscale() {
        editorState.isGrayscale.toggle()
        processImage()
    }
    
    func toggleSepia() {
        editorState.isSepia.toggle()
        processImage()
    }
    
    func setShapePreset(_ preset: IconEditorState.ShapePreset) {
        editorState.shapePreset = preset
        processImage()
    }
    
    func rotate(degrees: Double) {
        editorState.rotationAngle += degrees
        if editorState.rotationAngle >= 360 { editorState.rotationAngle -= 360 }
        if editorState.rotationAngle < 0 { editorState.rotationAngle += 360 }
        processImage()
    }
    
    func flipHorizontal() {
        editorState.isFlippedHorizontal.toggle()
        processImage()
    }
    
    func flipVertical() {
        editorState.isFlippedVertical.toggle()
        processImage()
    }
    
    func resetAll() {
        editorState.reset()
        processImage()
    }
    
    func resetAdjustments() {
        editorState.brightness = 0
        editorState.contrast = 0
        editorState.saturation = 0
        editorState.exposure = 0
        editorState.hue = 0
        editorState.sharpness = 0
        editorState.blur = 0
        editorState.vignette = 0
        editorState.isGrayscale = false
        editorState.isSepia = false
        processImage()
    }
    
    func applyIcon() async {
        guard let image = processedImage, let app = selectedApp else { return }
        
        if app.isSystemApp && !pendingSystemAppConfirmation {
            showSystemAppWarning = true
            return
        }
        
        isApplying = true
        applyError = nil
        applySuccess = false
        defer { isApplying = false }
        
        do {
            logger.info("Creating backup for \(app.bundleIdentifier)")
            _ = try backupManager.createBackup(for: app)
            
            let backend = BackendManager.shared.bestBackend()
            guard let backend else {
                throw IconForgeError.unsupportedOperation("No icon backend available")
            }
            
            logger.info("Applying icon using backend: \(backend.name)")
            try await backend.applyIcon(image, to: app)
            
            applySuccess = true
            logger.info("Successfully applied icon to \(app.displayName)")
        } catch {
            applyError = error.localizedDescription
            logger.error("Failed to apply icon: \(error.localizedDescription)")
        }
    }
    
    func resetEditor() {
        originalImage = nil
        processedImage = nil
        editorState = IconEditorState()
        selectedApp = nil
        isProcessing = false
        isApplying = false
        applySuccess = false
        applyError = nil
        showSystemAppWarning = false
        pendingSystemAppConfirmation = false
    }
    
    private func processImage() {
        guard let original = originalImage else { return }
        isProcessing = true
        defer { isProcessing = false }
        processedImage = renderer.renderIcon(
            from: original,
            state: editorState,
            targetSize: CGSize(width: 1024, height: 1024)
        )
    }
}

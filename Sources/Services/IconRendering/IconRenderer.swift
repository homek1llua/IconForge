import Foundation
import UIKit
import CoreImage
import ImageIO

final class IconRenderer: @unchecked Sendable {
    
    enum IconSize: Int, CaseIterable {
        case notification = 40
        case spotlight = 58
        case settings = 29
        case app_60 = 60
        case app_76 = 76
        case app_83_5 = 84
        case appStore = 1024
        
        var scaledSize: CGSize {
            CGSize(width: CGFloat(rawValue), height: CGFloat(rawValue))
        }
        
        var displayScale: CGFloat {
            switch self {
            case .notification, .spotlight, .settings: return 3
            case .app_60, .app_76, .app_83_5: return 2
            case .appStore: return 1
            }
        }
        
        var pixelSize: CGSize {
            CGSize(width: rawValue * Int(displayScale), height: rawValue * Int(displayScale))
        }
    }
    
    static let shared = IconRenderer()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    private init() {}
    
    func renderIcon(
        from image: UIImage,
        state: IconEditorState,
        targetSize: CGSize = CGSize(width: 1024, height: 1024)
    ) -> UIImage? {
        var currentImage = image
        
        if let cropped = applyCrop(to: currentImage, cropRect: state.cropRect) {
            currentImage = cropped
        }
        
        if state.rotationAngle != 0 || state.isFlippedHorizontal || state.isFlippedVertical {
            currentImage = applyTransforms(
                to: currentImage,
                rotation: state.rotationAngle,
                flipH: state.isFlippedHorizontal,
                flipV: state.isFlippedVertical
            ) ?? currentImage
        }
        
        if state.hasAdjustments {
            currentImage = applyAdjustments(to: currentImage, state: state) ?? currentImage
        }
        
        let backgroundApplied = applyBackground(
            to: currentImage,
            state: state,
            targetSize: targetSize
        )
        let finalImage = backgroundApplied ?? currentImage
        
        let masked = applyMask(
            to: finalImage,
            cornerRadius: state.effectiveCornerRadius,
            targetSize: targetSize
        )
        
        let result = masked ?? resizeImage(finalImage, to: targetSize)
        return result
    }
    
    func renderAllSizes(
        from image: UIImage,
        state: IconEditorState
    ) -> [IconSize: UIImage] {
        var results: [IconSize: UIImage] = [:]
        let masterIcon = renderIcon(from: image, state: state, targetSize: CGSize(width: 1024, height: 1024))
        guard let master = masterIcon else { return results }
        for size in IconSize.allCases {
            if let resized = resizeImage(master, to: size.pixelSize) {
                results[size] = resized
            }
        }
        return results
    }
    
    func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    func resizeImageMaintainingAspect(_ image: UIImage, maxSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let ratio = min(widthRatio, heightRatio, 1.0)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return resizeImage(image, to: newSize)
    }
    
    private func applyCrop(to image: UIImage, cropRect: CGRect?) -> UIImage? {
        guard let cropRect, let cgImage = image.cgImage else { return nil }
        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height
        let scaledRect = CGRect(
            x: cropRect.origin.x * scaleX,
            y: cropRect.origin.y * scaleY,
            width: cropRect.size.width * scaleX,
            height: cropRect.size.height * scaleY
        )
        guard let croppedCG = cgImage.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: croppedCG, scale: image.scale, orientation: .up)
    }
    
    private func applyTransforms(
        to image: UIImage,
        rotation: Double,
        flipH: Bool,
        flipV: Bool
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: CGFloat(rotation * .pi / 180))
        var scaleX: CGFloat = flipH ? -1 : 1
        var scaleY: CGFloat = flipV ? -1 : 1
        context.scaleBy(x: scaleX, y: scaleY)
        context.translateBy(x: -size.width / 2, y: -size.height / 2)
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func applyAdjustments(to image: UIImage, state: IconEditorState) -> UIImage? {
        guard let inputCIImage = CIImage(image: image) else { return nil }
        var output = inputCIImage
        
        if state.brightness != 0 || state.contrast != 0 {
            let brightnessFilter = CIFilter(name: "CIColorControls")!
            brightnessFilter.setValue(output, forKey: kCIInputImageKey)
            brightnessFilter.setValue(state.brightness / 100.0, forKey: kCIInputBrightnessKey)
            brightnessFilter.setValue(1.0 + state.contrast / 100.0, forKey: kCIInputContrastKey)
            brightnessFilter.setValue(1.0 + state.saturation / 100.0, forKey: kCIInputSaturationKey)
            if let result = brightnessFilter.outputImage { output = result }
        } else if state.saturation != 0 {
            let satFilter = CIFilter(name: "CIColorControls")!
            satFilter.setValue(output, forKey: kCIInputImageKey)
            satFilter.setValue(1.0 + state.saturation / 100.0, forKey: kCIInputSaturationKey)
            if let result = satFilter.outputImage { output = result }
        }
        
        if state.exposure != 0 {
            let exposureFilter = CIFilter(name: "CIExposureAdjust")!
            exposureFilter.setValue(output, forKey: kCIInputImageKey)
            exposureFilter.setValue(state.exposure / 100.0, forKey: kCIInputEVKey)
            if let result = exposureFilter.outputImage { output = result }
        }
        
        if state.hue != 0 {
            let hueFilter = CIFilter(name: "CIHueAdjust")!
            hueFilter.setValue(output, forKey: kCIInputImageKey)
            hueFilter.setValue(state.hue * .pi / 180.0, forKey: kCIInputAngleKey)
            if let result = hueFilter.outputImage { output = result }
        }
        
        if state.isGrayscale {
            let monoFilter = CIFilter(name: "CIColorControls")!
            monoFilter.setValue(output, forKey: kCIInputImageKey)
            monoFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            if let result = monoFilter.outputImage { output = result }
        }
        
        if state.isSepia {
            let sepiaFilter = CIFilter(name: "CISepiaTone")!
            sepiaFilter.setValue(output, forKey: kCIInputImageKey)
            sepiaFilter.setValue(1.0, forKey: kCIInputIntensityKey)
            if let result = sepiaFilter.outputImage { output = result }
        }
        
        if state.vignette != 0 {
            let vignetteFilter = CIFilter(name: "CIVignette")!
            vignetteFilter.setValue(output, forKey: kCIInputImageKey)
            vignetteFilter.setValue(state.vignette / 50.0, forKey: kCIInputIntensityKey)
            vignetteFilter.setValue(2.0, forKey: kCIInputRadiusKey)
            if let result = vignetteFilter.outputImage { output = result }
        }
        
        if state.blur > 0 {
            let blurFilter = CIFilter(name: "CIGaussianBlur")!
            blurFilter.setValue(output, forKey: kCIInputImageKey)
            blurFilter.setValue(state.blur, forKey: kCIInputRadiusKey)
            if let result = blurFilter.outputImage { output = result }
        }
        
        guard let context = CGContext(
            data: nil,
            width: Int(output.extent.width),
            height: Int(output.extent.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
    
    private func applyBackground(
        to image: UIImage,
        state: IconEditorState,
        targetSize: CGSize
    ) -> UIImage? {
        switch state.backgroundType {
        case .transparent, .image:
            return nil
        case .solidColor:
            guard let bgColor = state.backgroundColor else { return nil }
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { ctx in
                ctx.cgContext.setFillColor(bgColor)
                ctx.fill(CGRect(origin: .zero, size: targetSize))
                let imageSize = image.size
                let ratio = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
                let drawSize = CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
                let drawRect = CGRect(
                    x: (targetSize.width - drawSize.width) / 2,
                    y: (targetSize.height - drawSize.height) / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
                image.draw(in: drawRect)
            }
        case .gradient:
            guard state.gradientColors.count >= 2 else { return nil }
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { ctx in
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let colors = state.gradientColors as CFArray
                guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil) else { return }
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: targetSize.height),
                    options: []
                )
                let imageSize = image.size
                let ratio = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
                let drawSize = CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
                let drawRect = CGRect(
                    x: (targetSize.width - drawSize.width) / 2,
                    y: (targetSize.height - drawSize.height) / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
                image.draw(in: drawRect)
            }
        }
    }
    
    private func applyMask(
        to image: UIImage,
        cornerRadius: CGFloat,
        targetSize: CGSize
    ) -> UIImage? {
        guard cornerRadius > 0, let cgImage = image.cgImage else { return nil }
        let scaledRadius = cornerRadius * (targetSize.width / 1024.0)
        let rect = CGRect(origin: .zero, size: targetSize)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let path = UIBezierPath(roundedRect: rect, cornerRadius: scaledRadius)
        context.addPath(path.cgPath)
        context.clip()
        context.draw(cgImage, in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func encodePNG(_ image: UIImage) -> Data? {
        return image.pngData()
    }
    
    func decodeImage(from data: Data) -> UIImage? {
        return UIImage(data: data)
    }
}

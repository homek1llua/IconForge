import Foundation
import CoreGraphics

struct IconEditorState: Sendable {
    enum ShapePreset: String, CaseIterable, Sendable {
        case iosDefault = "iOS Default"
        case soft = "Soft"
        case rounded = "Rounded"
        case sharp = "Sharp"
        case circle = "Circle"
        case square = "Square"

        var cornerRadius: CGFloat {
            switch self {
            case .iosDefault: return 22.37
            case .soft: return 30
            case .rounded: return 15
            case .sharp: return 0
            case .circle: return 100
            case .square: return 0
            }
        }
    }

    enum BackgroundType: String, CaseIterable, Sendable {
        case transparent = "Transparent"
        case solidColor = "Solid Color"
        case gradient = "Gradient"
        case image = "Image"
    }

    var brightness: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
    var exposure: Double = 0
    var hue: Double = 0
    var sharpness: Double = 0
    var blur: Double = 0
    var vignette: Double = 0
    var isGrayscale: Bool = false
    var isSepia: Bool = false

    var backgroundColor: CGColor?
    var gradientColors: [CGColor] = []
    var backgroundType: BackgroundType = .transparent
    var shapePreset: ShapePreset = .iosDefault
    var customCornerRadius: CGFloat = 22.37
    var rotationAngle: Double = 0
    var isFlippedHorizontal: Bool = false
    var isFlippedVertical: Bool = false
    var cropRect: CGRect?

    var effectiveCornerRadius: CGFloat {
        if shapePreset == .iosDefault {
            return 22.37
        }
        return customCornerRadius
    }

    var hasAdjustments: Bool {
        brightness != 0 || contrast != 0 || saturation != 0 ||
        exposure != 0 || hue != 0 || sharpness != 0 ||
        blur != 0 || vignette != 0 || isGrayscale || isSepia
    }

    mutating func reset() {
        self = IconEditorState()
    }
}

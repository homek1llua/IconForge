import XCTest
@testable import IconForge

final class IconEditorStateTests: XCTestCase {
    
    func testDefaultState() {
        let state = IconEditorState()
        XCTAssertEqual(state.brightness, 0)
        XCTAssertEqual(state.contrast, 0)
        XCTAssertEqual(state.saturation, 0)
        XCTAssertEqual(state.exposure, 0)
        XCTAssertEqual(state.hue, 0)
        XCTAssertEqual(state.shapePreset, .iosDefault)
        XCTAssertFalse(state.isGrayscale)
        XCTAssertFalse(state.isSepia)
        XCTAssertFalse(state.hasAdjustments)
    }
    
    func testHasAdjustments() {
        var state = IconEditorState()
        XCTAssertFalse(state.hasAdjustments)
        
        state.brightness = 10
        XCTAssertTrue(state.hasAdjustments)
        
        state.brightness = 0
        XCTAssertFalse(state.hasAdjustments)
        
        state.isGrayscale = true
        XCTAssertTrue(state.hasAdjustments)
    }
    
    func testReset() {
        var state = IconEditorState()
        state.brightness = 50
        state.contrast = 30
        state.isGrayscale = true
        state.shapePreset = .circle
        
        state.reset()
        
        XCTAssertEqual(state.brightness, 0)
        XCTAssertEqual(state.contrast, 0)
        XCTAssertFalse(state.isGrayscale)
        XCTAssertEqual(state.shapePreset, .iosDefault)
    }
    
    func testShapePresetCornerRadius() {
        XCTAssertEqual(IconEditorState.ShapePreset.iosDefault.cornerRadius, 22.37)
        XCTAssertEqual(IconEditorState.ShapePreset.circle.cornerRadius, 100)
        XCTAssertEqual(IconEditorState.ShapePreset.sharp.cornerRadius, 0)
        XCTAssertEqual(IconEditorState.ShapePreset.square.cornerRadius, 0)
        XCTAssertGreaterThan(IconEditorState.ShapePreset.soft.cornerRadius, IconEditorState.ShapePreset.rounded.cornerRadius)
    }
    
    func testEffectiveCornerRadius() {
        var state = IconEditorState()
        XCTAssertEqual(state.effectiveCornerRadius, 22.37)
        
        state.shapePreset = .circle
        XCTAssertEqual(state.effectiveCornerRadius, 100)
    }
}

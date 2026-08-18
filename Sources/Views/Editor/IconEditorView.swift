import SwiftUI

struct IconEditorView: View {
    let app: InstalledApp
    @StateObject private var viewModel = IconEditorViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: EditorTab = .adjust
    @State private var showImagePicker = false
    @State private var showSourcePicker = false
    
    enum EditorTab: String, CaseIterable {
        case adjust = "Adjust"
        case effects = "Effects"
        case background = "Background"
        case shape = "Shape"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerBar
                imagePreview
                editorToolbar
                tabContent
            }
            .navigationTitle("Edit Icon")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.setApp(app)
                showSourcePicker = true
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    viewModel.loadImage(from: image)
                }
            }
            .sheet(isPresented: $showSourcePicker) {
                SourcePickerSheet { source in
                    switch source {
                    case .photoLibrary:
                        showImagePicker = true
                    case .files:
                        break
                    }
                }
            }
            .alert("System Application Warning", isPresented: $viewModel.showSystemAppWarning) {
                Button("Cancel", role: .cancel) { viewModel.cancelSystemApp() }
                Button("Continue") { viewModel.confirmSystemApp() }
            } message: {
                Text("This is a system application. Modifying its resources may cause SpringBoard or the application to behave unexpectedly. Proceed with caution.")
            }
            .alert("Success", isPresented: $viewModel.applySuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Custom icon applied successfully!")
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.applyError != nil },
                set: { if !$0 { viewModel.applyError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.applyError ?? "")
            }
        }
    }
    
    private var headerBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
            Spacer()
            Text(app.displayName)
                .font(.headline)
            Spacer()
            Button("Save") {
                Task { await viewModel.applyIcon() }
            }
            .disabled(!viewModel.canApply)
        }
        .padding()
    }
    
    private var imagePreview: some View {
        ZStack {
            Color.black.opacity(0.05)
            if let processed = viewModel.processedImage {
                Image(uiImage: processed)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 250, maxHeight: 250)
                    .cornerRadius(effectiveRadius)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            } else {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Tap to import an image")
                        .foregroundColor(.secondary)
                }
                .onTapGesture { showSourcePicker = true }
            }
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }
    
    private var effectiveRadius: CGFloat {
        switch viewModel.editorState.shapePreset {
        case .iosDefault: return 22.37
        case .soft: return 30
        case .rounded: return 15
        case .sharp: return 0
        case .circle: return 125
        case .square: return 0
        }
    }
    
    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(EditorTab.allCases, id: \.rawValue) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.caption.bold())
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.purple)
                                    .frame(height: 2)
                            }
                        }
                    }
                    .foregroundColor(selectedTab == tab ? .purple : .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .adjust: adjustTab
        case .effects: effectsTab
        case .background: backgroundTab
        case .shape: shapeTab
        }
    }
    
    private var adjustTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                adjustmentSlider("Brightness", value: Binding(
                    get: { viewModel.editorState.brightness },
                    set: { viewModel.updateBrightness($0) }
                ), range: -100...100)
                adjustmentSlider("Contrast", value: Binding(
                    get: { viewModel.editorState.contrast },
                    set: { viewModel.updateContrast($0) }
                ), range: -100...100)
                adjustmentSlider("Saturation", value: Binding(
                    get: { viewModel.editorState.saturation },
                    set: { viewModel.updateSaturation($0) }
                ), range: -100...100)
                adjustmentSlider("Exposure", value: Binding(
                    get: { viewModel.editorState.exposure },
                    set: { viewModel.updateExposure($0) }
                ), range: -100...100)
                adjustmentSlider("Hue", value: Binding(
                    get: { viewModel.editorState.hue },
                    set: { viewModel.updateHue($0) }
                ), range: 0...360)
                Button("Reset Adjustments") { viewModel.resetAdjustments() }
                    .foregroundColor(.red)
            }
            .padding()
        }
    }
    
    private var effectsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                adjustmentSlider("Blur", value: Binding(
                    get: { viewModel.editorState.blur },
                    set: { viewModel.updateBlur($0) }
                ), range: 0...20)
                adjustmentSlider("Vignette", value: Binding(
                    get: { viewModel.editorState.vignette },
                    set: { viewModel.updateVignette($0) }
                ), range: 0...100)
                HStack(spacing: 12) {
                    ToggleButton(title: "Grayscale", isOn: viewModel.editorState.isGrayscale) {
                        viewModel.toggleGrayscale()
                    }
                    ToggleButton(title: "Sepia", isOn: viewModel.editorState.isSepia) {
                        viewModel.toggleSepia()
                    }
                }
                HStack(spacing: 12) {
                    ActionButton(title: "Rotate Left", icon: "rotate.left") {
                        viewModel.rotate(degrees: -90)
                    }
                    ActionButton(title: "Rotate Right", icon: "rotate.right") {
                        viewModel.rotate(degrees: 90)
                    }
                    ActionButton(title: "Flip H", icon: "arrow.left.arrow.right") {
                        viewModel.flipHorizontal()
                    }
                    ActionButton(title: "Flip V", icon: "arrow.up.arrow.down") {
                        viewModel.flipVertical()
                    }
                }
                Button("Reset All") { viewModel.resetAll() }
                    .foregroundColor(.red)
            }
            .padding()
        }
    }
    
    private var backgroundTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Background options coming soon.")
                    .foregroundColor(.secondary)
                ColorPicker("Background Color", selection: Binding(
                    get: { Color(viewModel.editorState.backgroundColor ?? UIColor.white.cgColor) },
                    set: { newColor in
                        if let cgColor = newColor.cgColor {
                            viewModel.editorState.backgroundColor = cgColor
                            viewModel.editorState.backgroundType = .solidColor
                            viewModel.objectWillChange.send()
                        }
                    }
                ))
            }
            .padding()
        }
    }
    
    private var shapeTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(IconEditorState.ShapePreset.allCases, id: \.rawValue) { preset in
                    Button(action: { viewModel.setShapePreset(preset) }) {
                        HStack {
                            RoundedRectangle(cornerRadius: preset.cornerRadius)
                                .fill(Color.purple.opacity(viewModel.editorState.shapePreset == preset ? 0.3 : 0.1))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: preset.cornerRadius)
                                        .stroke(viewModel.editorState.shapePreset == preset ? Color.purple : Color.clear, lineWidth: 2)
                                )
                            Text(preset.rawValue)
                                .font(.body)
                            Spacer()
                            if viewModel.editorState.shapePreset == preset {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding()
        }
    }
    
    private func adjustmentSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
                .tint(.purple)
        }
    }
}

struct ToggleButton: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(isOn ? Color.purple : Color.gray.opacity(0.2)))
                .foregroundColor(isOn ? .white : .primary)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)))
        }
        .foregroundColor(.primary)
    }
}

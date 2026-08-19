import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onURLSelected: (URL) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .image
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onURLSelected(url)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

enum ImageSource: String, CaseIterable, Identifiable {
    case photoLibrary = "Photo Library"
    case files = "Files"
    var id: String { rawValue }
}

struct SourcePickerSheet: View {
    let onSelect: (ImageSource) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ImageSource.allCases) { source in
                    Button(action: {
                        onSelect(source)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: source == .photoLibrary ? "photo.on.rectangle" : "folder")
                                .foregroundColor(.purple)
                            Text(source.rawValue)
                        }
                    }
                }
            }
            .navigationBarTitle("Import Image", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

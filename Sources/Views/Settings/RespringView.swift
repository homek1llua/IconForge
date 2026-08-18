import SwiftUI

struct RespringView: View {
    @State private var selectedMethod: RespringMethod = .refreshIcons
    @State private var showConfirmation = false
    @State private var availableMethods: [RespringMethod] = []
    
    private let respringManager = RespringManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Respring")
                .font(.title.bold())
            
            ForEach(availableMethods) { method in
                Button(action: {
                    selectedMethod = method
                    if method.isDestructive {
                        showConfirmation = true
                    } else {
                        performRespring()
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(method.rawValue)
                                .font(.headline)
                            Text(method.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                }
                .foregroundColor(.primary)
            }
            
            if availableMethods.isEmpty {
                Text("No respring methods available.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            availableMethods = respringManager.availableRespringMethods()
        }
        .alert("Confirm Respring", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Respring", role: .destructive) { performRespring() }
        } message: {
            Text("This will \(selectedMethod.rawValue.lowercased()). Your screen may go black briefly.")
        }
    }
    
    private func performRespring() {
        try? respringManager.performRespring(selectedMethod)
    }
}

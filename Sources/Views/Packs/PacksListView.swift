import SwiftUI

struct PacksListView: View {
    @StateObject private var viewModel = PacksViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.packs.isEmpty {
                    emptyState
                } else {
                    packList
                }
            }
            .navigationTitle("Icon Packs")
            .navigationBarItems(trailing: Button(action: { viewModel.showingCreateSheet = true }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $viewModel.showingCreateSheet) {
                createPackSheet
            }
            .alert(isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? ""),
                    dismissButton: .default(Text("OK")) { viewModel.errorMessage = nil }
                )
            }
            .alert(isPresented: .init(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.successMessage = nil } }
            )) {
                Alert(
                    title: Text("Success"),
                    message: Text(viewModel.successMessage ?? ""),
                    dismissButton: .default(Text("OK")) { viewModel.successMessage = nil }
                )
            }
            .onAppear { viewModel.loadPacks() }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Icon Packs")
                .font(.title2.bold())
            Text("Create a new pack to save and share your custom icons.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Create Pack") { viewModel.showingCreateSheet = true }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple))
            Spacer()
        }
        .padding()
    }
    
    private var packList: some View {
        List(viewModel.packs) { pack in
            PackRow(pack: pack)
                .contextMenu {
                    Button { viewModel.deletePack(pack) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button { viewModel.duplicatePack(pack) } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Button { Task { await viewModel.exportPack(pack) } } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
        }
        .listStyle(.plain)
    }
    
    private var createPackSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Pack Details")) {
                    TextField("Pack Name", text: $viewModel.newPackName)
                    TextField("Description (optional)", text: $viewModel.newPackDescription)
                }
            }
            .navigationTitle("New Pack")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { viewModel.showingCreateSheet = false },
                trailing: Button("Create") { Task { await viewModel.createPack() } }
                    .disabled(viewModel.newPackName.isEmpty)
            )
        }
    }
}

struct PackRow: View {
    let pack: IconPack
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "tray.full")
                        .foregroundColor(.purple)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name)
                    .font(.headline)
                if !pack.description.isEmpty {
                    Text(pack.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                HStack {
                    Label("\(pack.iconCount) icons", systemImage: "app.fill")
                    Spacer()
                    Text(pack.modifiedAt.displayString)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

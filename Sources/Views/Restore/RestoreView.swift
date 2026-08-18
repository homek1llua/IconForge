import SwiftUI

struct RestoreView: View {
    @StateObject private var viewModel = RestoreViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.backups.isEmpty {
                    emptyState
                } else {
                    backupList
                }
            }
            .navigationTitle("Restore")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Restore All") { viewModel.showConfirmRestoreAll = true }
                        Button("Delete All", role: .destructive) { viewModel.showConfirmDeleteAll = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { viewModel.loadBackups() }
            .alert("Restore All Icons?", isPresented: $viewModel.showConfirmRestoreAll) {
                Button("Cancel", role: .cancel) {}
                Button("Restore All") { Task { await viewModel.restoreAll() } }
            } message: {
                Text("This will restore all \(viewModel.backups.count) original icons.")
            }
            .alert("Delete All Backups?", isPresented: $viewModel.showConfirmDeleteAll) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) { viewModel.deleteAllBackups() }
            } message: {
                Text("This action cannot be undone.")
            }
            .overlay {
                if viewModel.isRestoring {
                    ProgressView("Restoring... \(Int(viewModel.restoreProgress * 100))%")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Backups")
                .font(.title2.bold())
            Text("Backups are created automatically when you apply custom icons.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
    
    private var backupList: some View {
        List(viewModel.backups) { backup in
            BackupRow(backup: backup)
                .swipeActions(edge: .trailing) {
                    Button {
                        Task { await viewModel.restoreBackup(for: backup.bundleIdentifier) }
                    } label: {
                        Label("Restore", systemImage: "arrow.counterclockwise")
                    }
                    .tint(.green)
                    
                    Button(role: .destructive) {
                        viewModel.deleteBackup(for: backup.bundleIdentifier)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .listStyle(.plain)
    }
}

struct BackupRow: View {
    let backup: IconBackup
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(backup.appDisplayName)
                    .font(.headline)
                Text(backup.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Text(backup.createdAt.displayString)
                    Spacer()
                    Text(backup.iOSVersion)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

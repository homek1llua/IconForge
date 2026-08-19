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
            .navigationBarItems(trailing: Menu {
                Button("Restore All") { viewModel.showConfirmRestoreAll = true }
                Button("Delete All") { viewModel.showConfirmDeleteAll = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            })
            .onAppear { viewModel.loadBackups() }
            .alert(isPresented: $viewModel.showConfirmRestoreAll) {
                Alert(
                    title: Text("Restore All Icons?"),
                    message: Text("This will restore all \(viewModel.backups.count) original icons."),
                    primaryButton: .cancel(Text("Cancel")),
                    secondaryButton: .default(Text("Restore All")) { Task { await viewModel.restoreAll() } }
                )
            }
            .alert(isPresented: $viewModel.showConfirmDeleteAll) {
                Alert(
                    title: Text("Delete All Backups?"),
                    message: Text("This action cannot be undone."),
                    primaryButton: .cancel(Text("Cancel")),
                    secondaryButton: .destructive(Text("Delete All")) { viewModel.deleteAllBackups() }
                )
            }
            .overlay(
                Group {
                    if viewModel.isRestoring {
                        ProgressView("Restoring... \(Int(viewModel.restoreProgress * 100))%")
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                },
                alignment: .center
            )
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
                .contextMenu {
                    Button {
                        Task { await viewModel.restoreBackup(for: backup.bundleIdentifier) }
                    } label: {
                        Label("Restore", systemImage: "arrow.counterclockwise")
                    }
                    Button {
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

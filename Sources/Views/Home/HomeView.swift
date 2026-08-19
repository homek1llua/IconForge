import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: HomeViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if !viewModel.isJailbroken {
                        notJailbrokenCard
                    } else {
                        statusCard
                        statsGrid
                        quickActionsSection
                        recentActivitySection
                    }
                }
                .padding()
            }
            .navigationTitle("IconForge")
            .navigationBarItems(trailing: Button(action: { Task { await viewModel.refreshDashboard() } }) {
                Image(systemName: "arrow.clockwise")
            })
            .onAppear {
                Task { await viewModel.loadDashboard() }
            }
        }
    }
    
    private var notJailbrokenCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Jailbreak Not Detected")
                .font(.title2.bold())
            Text("IconForge requires a jailbroken device with root filesystem access to modify application icons.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
    }
    
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Text("Jailbreak Active")
                    .font(.headline)
                Spacer()
                Text(viewModel.jailbreakStatus?.environment.rawValue ?? "")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.green.opacity(0.2)))
            }
            HStack {
                Label("Backend: \(BackendManager.shared.backendName())", systemImage: "cpu")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            StatCard(title: "Apps", value: "\(viewModel.totalApps)", icon: "square.grid.2x2", color: .blue)
            StatCard(title: "Customized", value: "\(viewModel.customizedCount)", icon: "paintbrush.fill", color: .purple)
            StatCard(title: "Packs", value: "\(viewModel.packCount)", icon: "tray.full", color: .orange)
            StatCard(title: "Backups", value: "\(viewModel.backupCount)", icon: "arrow.down.circle", color: .green)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading) {
            Text("Quick Actions")
                .font(.headline)
            HStack(spacing: 12) {
                NavigationLink(destination: AppsListView()) {
                    QuickActionCard(title: "Browse Apps", icon: "list.bullet", color: .blue)
                }
                NavigationLink(destination: PacksListView()) {
                    QuickActionCard(title: "Icon Packs", icon: "tray.full", color: .orange)
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Activity")
                .font(.headline)
            if viewModel.recentActivity.isEmpty {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.recentActivity) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text(item.title).font(.subheadline.bold())
                            Text(item.subtitle).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

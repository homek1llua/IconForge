import SwiftUI

struct AppsListView: View {
    @StateObject private var viewModel = AppsViewModel()
    @State private var showIconEditor = false
    @State private var appToEdit: InstalledApp?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                filterBar
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading apps...")
                    Spacer()
                } else if viewModel.filteredApps.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    appList
                }
            }
            .navigationTitle("Installed Apps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        sortMenu
                        selectionMenu
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await viewModel.loadApps() }
            .refreshable { await viewModel.refreshApps() }
            .sheet(item: $appToEdit) { app in
                IconEditorView(app: app)
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search apps...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AppFilter.allCases) { filter in
                    Button(action: { viewModel.selectedFilter = filter }) {
                        Text(filter.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedFilter == filter ? Color.purple : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(viewModel.selectedFilter == filter ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private var appList: some View {
        List {
            if viewModel.hasSelection {
                SelectionBar(
                    selectedCount: viewModel.selectedCount,
                    onSelectAll: { viewModel.selectAll() },
                    onDeselectAll: { viewModel.deselectAll() }
                )
            }
            ForEach(viewModel.filteredApps) { app in
                AppRow(
                    app: app,
                    icon: viewModel.loadIcon(for: app),
                    isCustomized: viewModel.isCustomized(app),
                    isSelected: viewModel.selectedApps.contains(app.bundleIdentifier)
                ) {
                    appToEdit = app
                } onToggleSelect: {
                    viewModel.toggleSelection(for: app.bundleIdentifier)
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No apps found")
                .font(.headline)
            Text("Try adjusting your search or filter.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var sortMenu: some View {
        Menu("Sort By") {
            ForEach(AppSortOption.allCases) { option in
                Button(action: { viewModel.sortOption = option }) {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
    
    private var selectionMenu: some View {
        Menu("Select") {
            Button("Select All") { viewModel.selectAll() }
            Button("Deselect All") { viewModel.deselectAll() }
        }
    }
}

struct AppRow: View {
    let app: InstalledApp
    let icon: UIImage?
    let isCustomized: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .purple : .gray)
            }
            .buttonStyle(.plain)
            
            if let icon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .cornerRadius(10)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "app.fill").foregroundColor(.gray))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.body.bold())
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack {
                    if app.isSystemApp {
                        Label("System", systemImage: "lock.shield")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if isCustomized {
                        Label("Custom", systemImage: "paintbrush.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text("Original")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct SelectionBar: View {
    let selectedCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    
    var body: some View {
        HStack {
            Text("\(selectedCount) selected")
                .font(.subheadline.bold())
            Spacer()
            Button("All", action: onSelectAll)
            Button("None", action: onDeselectAll)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.1))
    }
}

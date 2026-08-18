import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                jailbreakSection
                generalSection
                iconBehaviorSection
                storageSection
                advancedSection
                diagnosticsSection
            }
            .navigationTitle("Settings")
            .task { viewModel.detectJailbreak(); viewModel.loadStorageInfo() }
        }
    }
    
    private var jailbreakSection: some View {
        Section("Jailbreak") {
            row("Environment", value: viewModel.jailbreakEnvironment)
            row("Root Path", value: viewModel.rootPath)
            row("Icon Backend", value: viewModel.backendName)
            Toggle("Rootless Mode", isOn: .constant(viewModel.isRootless))
                .disabled(true)
        }
    }
    
    private var generalSection: some View {
        Section("General") {
            Picker("Appearance", selection: $viewModel.appearance) {
                ForEach(AppAppearance.allCases) { Text($0.rawValue).tag($0) }
            }
            Toggle("Haptics", isOn: $viewModel.hapticsEnabled)
            Toggle("Animations", isOn: $viewModel.animationsEnabled)
        }
    }
    
    private var iconBehaviorSection: some View {
        Section("Icon Behavior") {
            Toggle("Auto-Refresh Cache", isOn: $viewModel.autoRefreshCache)
            Toggle("Auto-Respring", isOn: $viewModel.autoRespring)
            Toggle("Backup Before Modifying", isOn: $viewModel.backupBeforeModifying)
            Toggle("Preserve Original Icon", isOn: $viewModel.preserveOriginalIcon)
        }
    }
    
    private var storageSection: some View {
        Section("Storage") {
            if let info = viewModel.storageInfo {
                row("Total Used", value: info.formattedTotal)
                row("Backups", value: info.formattedBackups)
                row("Cache", value: info.formattedCache)
            }
            Button("Clear Cache") { viewModel.clearCache() }
                .foregroundColor(.red)
        }
    }
    
    private var advancedSection: some View {
        Section("Advanced") {
            Button("Rebuild Icon Database") { viewModel.rebuildIconDatabase() }
            Button("Clear Logs") { viewModel.clearLogs() }
            Button("Export Diagnostic Logs") {
                let logs = viewModel.exportDiagnosticLogs()
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("iconforge-logs.txt")
                try? logs.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            if let report = viewModel.diagnosticsReport {
                row("Jailbreak", value: report.jailbreakDetected ? "✓" : "✕")
                row("Environment", value: report.environment)
                row("iOS", value: report.iosVersion)
                row("Architecture", value: report.architecture)
                row("Root Access", value: report.rootAccess ? "✓" : "✕")
                row("LaunchServices", value: report.launchServicesAccess ? "✓" : "✕")
                row("Icon Backend", value: report.iconBackend)
                row("Cache Access", value: report.iconCacheAccess ? "✓" : "✕")
                row("Respring", value: report.respringCapability ? "✓" : "✕")
                row("Installed Apps", value: "\(report.installedAppsCount)")
                row("Customized", value: "\(report.customizedAppsCount)")
                row("Backups", value: "\(report.backupCount)")
                row("Storage", value: report.formattedStorageUsed)
            }
            Button("Run Diagnostics") { Task { await viewModel.runDiagnostics() } }
                .disabled(viewModel.isRunningDiagnostics)
        }
    }
    
    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

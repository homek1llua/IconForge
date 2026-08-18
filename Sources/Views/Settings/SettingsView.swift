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
            LabeledContent("Environment", value: viewModel.jailbreakEnvironment)
            LabeledContent("Root Path", value: viewModel.rootPath)
            LabeledContent("Icon Backend", value: viewModel.backendName)
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
                LabeledContent("Total Used", value: info.formattedTotal)
                LabeledContent("Backups", value: info.formattedBackups)
                LabeledContent("Cache", value: info.formattedCache)
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
                LabeledContent("Jailbreak", value: report.jailbreakDetected ? "✓" : "✕")
                LabeledContent("Environment", value: report.environment)
                LabeledContent("iOS", value: report.iosVersion)
                LabeledContent("Architecture", value: report.architecture)
                LabeledContent("Root Access", value: report.rootAccess ? "✓" : "✕")
                LabeledContent("LaunchServices", value: report.launchServicesAccess ? "✓" : "✕")
                LabeledContent("Icon Backend", value: report.iconBackend)
                LabeledContent("Cache Access", value: report.iconCacheAccess ? "✓" : "✕")
                LabeledContent("Respring", value: report.respringCapability ? "✓" : "✕")
                LabeledContent("Installed Apps", value: "\(report.installedAppsCount)")
                LabeledContent("Customized", value: "\(report.customizedAppsCount)")
                LabeledContent("Backups", value: "\(report.backupCount)")
                LabeledContent("Storage", value: report.formattedStorageUsed)
            }
            Button("Run Diagnostics") { Task { await viewModel.runDiagnostics() } }
                .disabled(viewModel.isRunningDiagnostics)
        }
    }
}

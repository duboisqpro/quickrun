import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

/// App-level settings: appearance, startup, data, and app info.
struct SettingsView: View {
    @AppStorage(SettingsKey.theme)         private var theme:         AppTheme = .system
    @AppStorage(SettingsKey.launchAtLogin) private var launchAtLogin: Bool     = false

    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var workspaceStore: WorkspaceStore

    @State private var showImportConfirm = false
    @State private var pendingImport:    ExportBundle? = nil
    @State private var exportError:      String?       = nil
    @State private var importError:      String?       = nil
    @State private var showResetSheet    = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.title2).bold()
                Spacer()
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $theme) {
                        ForEach(AppTheme.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Startup") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { enabled in
                            setLaunchAtLogin(enabled)
                        }
                }

                Section("Data") {
                    LabeledContent("Export") {
                        Button("Export configuration…") { exportData() }
                            .buttonStyle(.bordered)
                    }
                    if let err = exportError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }

                    LabeledContent("Import") {
                        Button("Import configuration…") { importData() }
                            .buttonStyle(.bordered)
                    }
                    if let err = importError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }

                    LabeledContent("") {
                        Text("Import replaces all existing actions and workspaces.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Reset") {
                        Button("Reset all data…") { showResetSheet = true }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                }

                Section("About") {
                    LabeledContent("Version") {
                        Text(
                            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                            ?? "1.0"
                        )
                        .foregroundStyle(.secondary)
                    }
                    LabeledContent("Note") {
                        Text("Scripts run with your user privileges. Quickrun is not sandboxed.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 4)

            Spacer()
        }
        .sheet(isPresented: $showResetSheet) {
            ResetConfirmSheet {
                actionStore.actions.forEach    { actionStore.trash($0) }
                actionStore.emptyTrash()
                workspaceStore.workspaces.forEach { workspaceStore.delete($0) }
            }
        }
        .confirmationDialog(
            "Replace current configuration?",
            isPresented: $showImportConfirm,
            titleVisibility: .visible
        ) {
            Button("Import and replace", role: .destructive) {
                guard let bundle = pendingImport else { return }
                applyImport(bundle)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let bundle = pendingImport {
                Text("\(bundle.actions.count) action(s) and \(bundle.workspaces.count) workspace(s) will replace the current configuration.")
            }
        }
    }

    // MARK: - Export

    private func exportData() {
        exportError = nil
        let bundle = ExportBundle(
            actions:    actionStore.actions,
            workspaces: workspaceStore.workspaces
        )
        guard let data = try? JSONEncoder().encode(bundle) else {
            exportError = "Erreur d'encodage."
            return
        }

        let panel = NSSavePanel()
        panel.title              = "Export Quickrun configuration"
        panel.nameFieldStringValue = "quickrun-export"
        panel.allowedContentTypes  = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            exportError = "Could not write file: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    private func importData() {
        importError = nil
        let panel = NSOpenPanel()
        panel.title               = "Import Quickrun configuration"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data   = try Data(contentsOf: url)
            let bundle = try JSONDecoder().decode(ExportBundle.self, from: data)
            pendingImport    = bundle
            showImportConfirm = true
        } catch {
            importError = "Invalid or incompatible file."
        }
    }

    private func applyImport(_ bundle: ExportBundle) {
        // Only add workspaces that don't already exist (compared by ID)
        let existingIds = Set(workspaceStore.workspaces.map { $0.id })
        bundle.workspaces
            .filter { !existingIds.contains($0.id) }
            .forEach { workspaceStore.add($0) }

        // Replace all actions
        for action in actionStore.actions { actionStore.trash(action) }
        bundle.actions.forEach { actionStore.add($0) }
    }

    // MARK: - Launch at login

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else        { try SMAppService.mainApp.unregister() }
        } catch {
            // SMAppService may fail outside a properly signed bundle.
        }
    }
}

// MARK: - Reset confirmation sheet

private struct ResetConfirmSheet: View {
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""

    private let keyword = "RESET"
    private var isValid: Bool { typed.uppercased() == keyword }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Full reset")
                .font(.title2).bold()

            Text("All actions, workspaces and the trash will be **permanently deleted**. This cannot be undone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Type **\(keyword)** to confirm:")
                    .font(.subheadline)
                TextField("", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 200)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Reset") {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!isValid)
            }
        }
        .padding(32)
        .frame(width: 400)
    }
}

// MARK: - Export bundle

struct ExportBundle: Codable {
    var actions:    [Action]
    var workspaces: [Workspace]
}

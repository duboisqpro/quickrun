import SwiftUI

/// Shows all configured actions as an advanced tile grid.
struct ActionsView: View {
    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var runStore:       RunStore
    @EnvironmentObject var workspaceStore: WorkspaceStore

    @State private var filterWorkspaceId: UUID?   = nil
    @State private var isCreating                 = false
    @State private var editingAction:    Action?  = nil
    @State private var actionToTrash:    Action?  = nil
    @State private var logAction:        Action?  = nil
    @State private var showTrashAlert             = false

    private var filteredActions: [Action] {
        guard let id = filterWorkspaceId else { return actionStore.actions }
        return actionStore.actions.filter { $0.workspaceId == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            workspaceFilterBar
            if !workspaceStore.workspaces.isEmpty { Divider() }
            content
        }
        .sheet(isPresented: $isCreating) {
            ActionFormView(mode: .create) { actionStore.add($0) }
                .environmentObject(workspaceStore)
        }
        .sheet(item: $editingAction) { action in
            ActionFormView(mode: .edit(action)) { actionStore.update($0) }
                .environmentObject(workspaceStore)
        }
        .sheet(item: $logAction) { action in
            ActionLogSheet(action: action)
                .environmentObject(runStore)
        }
        .confirmationDialog(
            "Delete \"\(actionToTrash?.name ?? "")\"?",
            isPresented: $showTrashAlert,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                guard let action = actionToTrash else { return }
                if runStore.isRunning(actionId: action.id) { runStore.toggle(action: action) }
                actionStore.trash(action)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The action will be moved to the trash. You can restore it later.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Actions").font(.title2).bold()
            Spacer()
            Button { isCreating = true } label: {
                Label("New Action", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 12)
    }

    // MARK: - Workspace filter bar

    @ViewBuilder
    private var workspaceFilterBar: some View {
        if !workspaceStore.workspaces.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(label: "All", color: nil, active: filterWorkspaceId == nil) {
                        filterWorkspaceId = nil
                    }
                    ForEach(workspaceStore.workspaces) { ws in
                        filterChip(label: ws.name, color: ws.color.color, active: filterWorkspaceId == ws.id) {
                            filterWorkspaceId = ws.id
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }

    private func filterChip(label: String, color: Color?, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let color { Circle().fill(color).frame(width: 8, height: 8) }
                Text(label).font(.subheadline).fontWeight(active ? .semibold : .regular)
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(active ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor)))
            .overlay(Capsule().strokeBorder(active ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor), lineWidth: 1))
            .foregroundStyle(active ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tile grid

    @ViewBuilder
    private var content: some View {
        if filteredActions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 48)).foregroundStyle(.secondary)
                Text(actionStore.actions.isEmpty ? "No Actions" : "No actions in this workspace")
                    .font(.title3).bold()
                Text(actionStore.actions.isEmpty
                     ? "Tap \"New Action\" to add a script or command."
                     : "Switch filter or create an action in this workspace.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(filteredActions) { action in
                        ActionTile(
                            action:    action,
                            workspace: workspaceStore.workspace(for: action.workspaceId),
                            onEdit:    { editingAction = action },
                            onDelete:  { actionToTrash = action; showTrashAlert = true },
                            onLogs:    { logAction = action }
                        )
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Action Tile

private struct ActionTile: View {
    let action:    Action
    let workspace: Workspace?
    let onEdit:    () -> Void
    let onDelete:  () -> Void
    let onLogs:    () -> Void

    @EnvironmentObject var runStore: RunStore

    private var isRunning: Bool { runStore.isRunning(actionId: action.id) }

    private var lastRun: Run? {
        runStore.runs.first { $0.actionId == action.id }
    }

    private var tileBackground: Color {
        if isRunning { return Color.green.opacity(0.12) }
        switch lastRun?.status {
        case .finished: return Color.blue.opacity(0.08)
        case .error:    return Color.orange.opacity(0.12)
        default:        return Color(NSColor.controlBackgroundColor)
        }
    }

    private var tileBorderColor: Color {
        if isRunning { return Color.green.opacity(0.4) }
        switch lastRun?.status {
        case .finished: return Color.blue.opacity(0.35)
        case .error:    return Color.orange.opacity(0.4)
        default:        return Color(NSColor.separatorColor)
        }
    }

    private var tileBorderWidth: CGFloat { isRunning ? 1.5 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tileHeader
            Divider().padding(.horizontal, 12)
            tileBody
            Divider().padding(.horizontal, 12)
            tileFooter
        }
        .background(
            RoundedRectangle(cornerRadius: 10).fill(tileBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tileBorderColor, lineWidth: tileBorderWidth)
        )
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    // Status bar + badges
    private var tileHeader: some View {
        HStack(spacing: 6) {
            // Running indicator
            Circle()
                .fill(isRunning ? Color.green : Color.red.opacity(0.6))
                .frame(width: 9, height: 9)
            Text(isRunning ? "Running" : "Idle")
                .font(.caption2)
                .foregroundStyle(isRunning ? Color.green : Color.secondary)

            Spacer()

            // Shell badge
            Text(action.shell.label)
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(Color(NSColor.quaternaryLabelColor)))
                .foregroundStyle(.secondary)

            // Workspace badge
            if let ws = workspace {
                HStack(spacing: 3) {
                    Circle().fill(ws.color.color).frame(width: 6, height: 6)
                    Text(ws.name).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(ws.color.color.opacity(0.1)))
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.red.opacity(0.7))
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .help("Delete action")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // Name + command + cwd
    private var tileBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(action.name)
                .font(.headline)
                .lineLimit(1)

            Text(action.command.components(separatedBy: .newlines).first ?? action.command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let cwd = action.workingDirectory, !cwd.isEmpty {
                Label(cwd, systemImage: "folder")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            // Last run status
            HStack(spacing: 4) {
                if let run = lastRun {
                    Circle().fill(run.status.color).frame(width: 5, height: 5)
                    Text("Last run \(run.startedAt, style: .relative) ago — \(run.status.label)")
                } else {
                    Circle().fill(Color.secondary.opacity(0.4)).frame(width: 5, height: 5)
                    Text("Never run")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Run / Edit / Logs buttons
    private var tileFooter: some View {
        HStack(spacing: 8) {
            // Run / Stop — primary action
            Button {
                runStore.toggle(action: action)
            } label: {
                Label(isRunning ? "Stop" : "Run",
                      systemImage: isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? .red : .green)
            .controlSize(.small)

            // Edit
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Edit action")

            // Logs
            Button { onLogs() } label: {
                Label("Logs", systemImage: "text.alignleft")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("View logs")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Log Sheet

/// Full-size log viewer for a specific action (all its runs).
struct ActionLogSheet: View {
    let action: Action

    @EnvironmentObject var runStore: RunStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRunId: UUID?

    private var actionRuns: [Run] {
        runStore.runs.filter { $0.actionId == action.id }
    }

    private var selectedRun: Run? {
        runStore.runs.first { $0.id == selectedRunId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Logs — \(action.name)").font(.title2).bold()
                    Text("\(actionRuns.count) run\(actionRuns.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding(20)

            Divider()

            if actionRuns.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("No runs yet for this action.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                  HStack(spacing: 0) {
                    // Run list — 1/4
                    List(actionRuns, selection: $selectedRunId) { run in
                        HStack(spacing: 8) {
                            Circle().fill(run.status.color).frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(run.startedAt, style: .date).font(.subheadline)
                                Text(run.startedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(run.status.label).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .tag(run.id)
                    }
                    .frame(width: 220)
                    .onAppear { selectedRunId = actionRuns.first?.id }

                    Divider()

                    // Log viewer — 3/4
                    VStack(spacing: 0) {
                        if let run = selectedRun {
                            HStack {
                                Text(run.startedAt, format: .dateTime).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(run.status.label).font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(run.status.color.opacity(0.15)))
                                    .foregroundStyle(run.status.color)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            Divider()
                        }
                        LogsView(runId: selectedRunId)
                    }
                    .frame(maxWidth: .infinity)
                  }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}

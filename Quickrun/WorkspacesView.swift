import SwiftUI

/// Dedicated tab for creating, editing, and deleting workspaces.
struct WorkspacesView: View {
    @EnvironmentObject var workspaceStore: WorkspaceStore
    @EnvironmentObject var actionStore:    ActionStore

    @State private var isAdding   = false
    @State private var editingWs: Workspace? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Workspaces").font(.title2).bold()
                Spacer()
                Button { isAdding = true } label: {
                    Label("New Workspace", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            if workspaceStore.workspaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("No Workspaces").font(.title3).bold()
                    Text("Group your actions into workspaces for quick filtering.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(workspaceStore.workspaces) { ws in
                        HStack(spacing: 12) {
                            Circle().fill(ws.color.color).frame(width: 14, height: 14)
                            Text(ws.name).font(.headline)
                            Spacer()
                            let count = actionStore.actions.filter { $0.workspaceId == ws.id }.count
                            Text("\(count) action\(count == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(.secondary)
                            Button { editingWs = ws } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indices in
                        indices.forEach { workspaceStore.delete(workspaceStore.workspaces[$0]) }
                    }
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            WorkspaceFormView(mode: .create) { workspaceStore.add($0) }
        }
        .sheet(item: $editingWs) { ws in
            WorkspaceFormView(mode: .edit(ws)) { workspaceStore.update($0) }
        }
    }
}

// MARK: - Workspace Form

struct WorkspaceFormView: View {
    enum Mode { case create; case edit(Workspace) }
    let mode: Mode
    let onSave: (Workspace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name:  String         = ""
    @State private var color: WorkspaceColor = .blue

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(mode.title).font(.title2).bold()
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Button("Save") {
                    var ws: Workspace
                    switch mode {
                    case .create:      ws = Workspace(name: name.trimmingCharacters(in: .whitespaces), color: color)
                    case .edit(let e): ws = e; ws.name = name.trimmingCharacters(in: .whitespaces); ws.color = color
                    }
                    onSave(ws); dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(20)
            Divider()
            Form {
                TextField("Name", text: $name)
                Picker("Color", selection: $color) {
                    ForEach(WorkspaceColor.allCases) { c in
                        HStack {
                            Circle().fill(c.color).frame(width: 12, height: 12)
                            Text(c.label)
                        }
                        .tag(c)
                    }
                }
            }
            .formStyle(.grouped).padding(.horizontal, 4)
            Spacer()
        }
        .frame(minWidth: 360, minHeight: 240)
        .onAppear {
            if case .edit(let ws) = mode { name = ws.name; color = ws.color }
        }
    }
}

extension WorkspaceFormView.Mode {
    var title: String {
        switch self { case .create: return "New Workspace"; case .edit: return "Edit Workspace" }
    }
}

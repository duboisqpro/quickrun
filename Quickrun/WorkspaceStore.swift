import Foundation
import Combine

/// Persists the list of workspaces to disk.
final class WorkspaceStore: ObservableObject {
    @Published var workspaces: [Workspace] = []

    private let fileURL: URL

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Quickrun")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("workspaces.json")
        load()
    }

    func add(_ workspace: Workspace) {
        workspaces.append(workspace)
        save()
    }

    func update(_ workspace: Workspace) {
        guard let idx = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[idx] = workspace
        save()
    }

    func delete(_ workspace: Workspace) {
        workspaces.removeAll { $0.id == workspace.id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        workspaces.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func workspace(for id: UUID?) -> Workspace? {
        guard let id else { return nil }
        return workspaces.first { $0.id == id }
    }

    private func load() {
        guard
            let data    = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([Workspace].self, from: data)
        else { return }
        workspaces = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(workspaces) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

import Foundation
import Combine

/// Persists the user's list of actions (and trash) to JSON files in Application Support.
final class ActionStore: ObservableObject {
    @Published var actions:        [Action]        = []
    @Published var trashedActions: [TrashedAction] = []

    private let actionsURL: URL
    private let trashURL:   URL

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Quickrun")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.actionsURL = dir.appendingPathComponent("actions.json")
        self.trashURL   = dir.appendingPathComponent("trash.json")
        load()
    }

    // MARK: - Active actions

    func add(_ action: Action) {
        actions.append(action)
        saveActions()
    }

    func update(_ action: Action) {
        guard let idx = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[idx] = action
        saveActions()
    }

    func move(from srcId: UUID, to dstId: UUID) {
        guard let srcIdx = actions.firstIndex(where: { $0.id == srcId }),
              let dstIdx = actions.firstIndex(where: { $0.id == dstId })
        else { return }
        actions.move(fromOffsets: IndexSet(integer: srcIdx),
                     toOffset: dstIdx > srcIdx ? dstIdx + 1 : dstIdx)
        saveActions()
    }

    /// Moves an action to the trash instead of deleting it permanently.
    func trash(_ action: Action) {
        actions.removeAll { $0.id == action.id }
        trashedActions.insert(TrashedAction(action: action, trashedAt: Date()), at: 0)
        saveActions()
        saveTrash()
    }

    // MARK: - Trash

    /// Restores a trashed action back to the active list.
    func restore(_ trashed: TrashedAction) {
        trashedActions.removeAll { $0.id == trashed.id }
        actions.append(trashed.action)
        saveActions()
        saveTrash()
    }

    /// Permanently deletes a trashed action — cannot be undone.
    func permanentlyDelete(_ trashed: TrashedAction) {
        trashedActions.removeAll { $0.id == trashed.id }
        saveTrash()
    }

    /// Permanently deletes all trashed actions.
    func emptyTrash() {
        trashedActions.removeAll()
        saveTrash()
    }

    // MARK: - Persistence

    private func load() {
        if let data    = try? Data(contentsOf: actionsURL),
           let decoded = try? JSONDecoder().decode([Action].self, from: data) {
            actions = decoded
        }
        if let data    = try? Data(contentsOf: trashURL),
           let decoded = try? JSONDecoder().decode([TrashedAction].self, from: data) {
            trashedActions = decoded
        }
    }

    private func saveActions() {
        guard let data = try? JSONEncoder().encode(actions) else { return }
        try? data.write(to: actionsURL, options: .atomic)
    }

    private func saveTrash() {
        guard let data = try? JSONEncoder().encode(trashedActions) else { return }
        try? data.write(to: trashURL, options: .atomic)
    }
}

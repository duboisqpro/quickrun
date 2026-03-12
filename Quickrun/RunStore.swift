import Foundation
import Combine

/// Manages run lifecycle and keeps the in-memory run history.
/// At most one run per action is active at a time (mono-instance).
final class RunStore: ObservableObject {
    @Published var runs: [Run] = []

    /// Accumulated log text per run (run.id → full output string).
    private(set) var logs: [UUID: String] = [:]

    private var runners:      [UUID: ProcessRunner] = [:]  // run.id  → runner
    private var activeRunIds: [UUID: UUID]           = [:]  // action.id → run.id

    // MARK: - Public API

    func isRunning(actionId: UUID) -> Bool {
        activeRunIds[actionId] != nil
    }

    func log(for runId: UUID) -> String {
        logs[runId] ?? ""
    }

    /// Start the action if idle, stop it if currently running.
    func toggle(action: Action) {
        if let runId = activeRunIds[action.id] {
            runners[runId]?.stop()
        } else {
            launch(action: action)
        }
    }

    /// Terminate all running processes (call on app quit).
    func stopAll() {
        runners.values.forEach { $0.stop() }
    }

    /// Remove all non-running runs from the history.
    func clearFinished() {
        runs.removeAll { $0.status != .running }
    }

    // MARK: - Private

    private func launch(action: Action) {
        let run = Run(
            actionId:   action.id,
            actionName: action.name,
            startedAt:  Date(),
            status:     .running
        )
        let runId = run.id

        runs.insert(run, at: 0)
        logs[runId]          = ""
        activeRunIds[action.id] = runId

        let runner = ProcessRunner()
        runners[runId] = runner

        runner.onOutput = { [weak self] text in
            guard let self else { return }
            // Manually trigger objectWillChange because dictionary mutations
            // are not automatically detected by @Published.
            self.objectWillChange.send()
            self.logs[runId, default: ""] += text
        }

        runner.onTermination = { [weak self] code, status in
            guard let self else { return }
            if let idx = self.runs.firstIndex(where: { $0.id == runId }) {
                self.runs[idx].status   = status
                self.runs[idx].exitCode = code
            }
            self.runners.removeValue(forKey: runId)
            self.activeRunIds.removeValue(forKey: action.id)
        }

        do {
            try runner.start(action: action)
        } catch {
            if let idx = runs.firstIndex(where: { $0.id == runId }) {
                runs[idx].status = .error
            }
            runners.removeValue(forKey: runId)
            activeRunIds.removeValue(forKey: action.id)
            objectWillChange.send()
            logs[runId, default: ""] += "Launch error: \(error.localizedDescription)\n"
        }
    }
}

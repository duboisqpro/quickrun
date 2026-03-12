import SwiftUI

/// Shows the history of runs with a log viewer for the selected run.
struct RunsView: View {
    @EnvironmentObject var runStore: RunStore

    @State private var selectedRunId: UUID?

    private var selectedRun: Run? {
        runStore.runs.first { $0.id == selectedRunId }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                runsList
                    .frame(width: 220)
                Divider()
                logsPanel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Left: Runs List

    private var runsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Runs")
                    .font(.title2).bold()
                Spacer()
                if !runStore.runs.isEmpty {
                    Button("Clear") { runStore.clearFinished() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            if runStore.runs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Runs Yet")
                        .font(.title3).bold()
                    Text("Run an action to see its history here.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(runStore.runs, selection: $selectedRunId) { run in
                    RunRowView(run: run)
                        .tag(run.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Right: Log Viewer

    private var logsPanel: some View {
        VStack(spacing: 0) {
            logsPanelHeader
            Divider()
            LogsView(runId: selectedRunId)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var logsPanelHeader: some View {
        HStack {
            if let run = selectedRun {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.actionName).font(.headline)
                    Text(run.startedAt, format: .dateTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: run.status)
            } else {
                Text("Select a run to view its logs")
                    .foregroundStyle(.secondary)
            }
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 12)
    }
}

// MARK: - Run Row

private struct RunRowView: View {
    let run: Run

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(run.status.color)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(run.actionName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(run.startedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(run.status.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: RunStatus

    var body: some View {
        Text(status.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}

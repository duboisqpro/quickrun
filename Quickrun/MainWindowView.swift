import SwiftUI

/// Root view of the main Quickrun window.
struct MainWindowView: View {
    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var runStore:       RunStore
    @EnvironmentObject var workspaceStore: WorkspaceStore

    @State private var selectedTab: Tab = .actions

    enum Tab: String, CaseIterable, Identifiable {
        case actions    = "Actions"
        case runs       = "Runs & Logs"
        case workspaces = "Workspaces"
        case trash      = "Trash"
        case settings   = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .actions:    return "play.rectangle.fill"
            case .runs:       return "clock.fill"
            case .workspaces: return "square.3.layers.3d.fill"
            case .trash:      return "trash.fill"
            case .settings:   return "gearshape.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 155, ideal: 175)
        } detail: {
            Group {
                switch selectedTab {
                case .actions:
                    ActionsView()
                case .runs:
                    RunsView()
                case .workspaces:
                    WorkspacesView()
                        .environmentObject(workspaceStore)
                        .environmentObject(actionStore)
                case .trash:
                    TrashView()
                        .environmentObject(actionStore)
                case .settings:
                    SettingsView()
                        .environmentObject(actionStore)
                        .environmentObject(workspaceStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Quickrun")
        .onReceive(NotificationCenter.default.publisher(for: .quickrunNavigateToRuns)) { _ in
            selectedTab = .runs
        }
    }
}

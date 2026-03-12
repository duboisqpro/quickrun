import SwiftUI

/// Root view of the main Quickrun window.
struct MainWindowView: View {
    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var runStore:       RunStore
    @EnvironmentObject var workspaceStore: WorkspaceStore

    enum Tab: String, CaseIterable, Identifiable {
        case workspaces = "Workspaces"
        case actions    = "Actions"
        case runs       = "Runs & Logs"
        case trash      = "Trash"
        case settings   = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .workspaces: return "folder.fill"
            case .actions:    return "bolt.fill"
            case .runs:       return "clock.fill"
            case .trash:      return "trash.fill"
            case .settings:   return "gearshape.fill"
            }
        }
    }

    @State private var selectedTab: Tab = .workspaces

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

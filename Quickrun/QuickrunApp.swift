import SwiftUI

@main
struct QuickrunApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Read theme directly — @AppStorage here is safe (not inside ObservableObject)
    @AppStorage(SettingsKey.theme) private var theme: AppTheme = .system

    var body: some Scene {
        WindowGroup("Quickrun") {
            MainWindowView()
                .environmentObject(appDelegate.actionStore)
                .environmentObject(appDelegate.runStore)
                .environmentObject(appDelegate.workspaceStore)
                .preferredColorScheme(theme.colorScheme)
                .onReceive(
                    NotificationCenter.default.publisher(for: .quickrunOpenMainWindow)
                ) { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 860, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

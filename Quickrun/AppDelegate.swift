import AppKit
import SwiftUI

/// Manages the NSStatusItem (menu bar icon) and the NSPopover (panel).
/// Also owns the shared state objects so they outlive any individual view.
class AppDelegate: NSObject, NSApplicationDelegate {

    // Shared stores — injected into views as environment objects
    let actionStore    = ActionStore()
    let runStore       = RunStore()
    let workspaceStore = WorkspaceStore()

    private var statusItem: NSStatusItem!
    private var popover:    NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app alive when the main window is closed; it lives in the menu bar.
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        runStore.stopAll()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "bolt.circle.fill",
            accessibilityDescription: "Quickrun"
        )
        button.action = #selector(togglePanel)
        button.target = self
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Popover / Panel

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        let hosting = NSHostingController(
            rootView: PanelView(openMainWindow: { [weak self] in self?.openMainWindow() })
                .environmentObject(actionStore)
                .environmentObject(runStore)
                .environmentObject(workspaceStore)
        )
        // Let SwiftUI drive the popover height so it fits all content automatically.
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
    }

    // MARK: - Main Window

    /// Brings the main WindowGroup window to the front, creating it if needed.
    /// Optionally posts a navigation notification so the window switches to a specific tab.
    func openMainWindow(then notification: Notification.Name? = nil) {
        popover.performClose(nil)

        if let name = notification {
            NotificationCenter.default.post(name: name, object: nil)
        }

        // Titled windows are real app windows; borderless ones are popovers / overlays.
        if let window = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // No window yet — ask the SwiftUI scene to create one.
        NotificationCenter.default.post(name: .quickrunOpenMainWindow, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let quickrunOpenMainWindow  = Notification.Name("quickrunOpenMainWindow")
    static let quickrunNavigateToRuns  = Notification.Name("quickrunNavigateToRuns")
}

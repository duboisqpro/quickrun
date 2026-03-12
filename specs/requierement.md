# Quickrun — Requirements & guidance for implementers

This file defines project rules and practical guidance for anyone (human or AI) implementing Quickrun. The canonical product spec is [spec.md](spec.md).

---

## 1. General principles

- **Keep documentation up to date**: when you add or change behaviour, update [spec.md](spec.md) or this file so they stay in sync.
- **Native macOS only**: Swift, SwiftUI, and Foundation. No Electron, no web view for core UI.
- **Code quality**: clear, concise, single-purpose types and functions.
- **Language**: all code, comments, commit messages, and user-facing strings must be in **English**.
- **Identifiers**: `PascalCase` for types/protocols, `camelCase` for properties/methods/locals.

---

## 2. Tech stack

| Concern | Solution |
|---------|----------|
| Language | Swift 5.9 |
| UI | SwiftUI; AppKit where required |
| Menu bar icon | `NSStatusItem` (variable length) with `bolt.circle.fill` SF Symbol |
| Panel | `NSPopover` (transient behaviour); `NSHostingController` with `sizingOptions = .preferredContentSize` for dynamic height |
| Main window | SwiftUI `WindowGroup` via `@NSApplicationDelegateAdaptor`; `NavigationSplitView` with sidebar |
| Process execution | `Foundation.Process` + `Pipe` for stdout/stderr; `Process.terminate()` to stop |
| Persistence | JSON files in `Application Support/Quickrun/` via `JSONEncoder`/`JSONDecoder` |
| Preferences | `@AppStorage` directly in views (NOT inside `ObservableObject` — causes publish warnings) |
| Launch at login | `SMAppService.mainApp` (ServiceManagement framework) |
| Minimum target | macOS 13 Ventura |

---

## 3. Project structure

```
Quickrun/
├── Models.swift          # All data types: Action, Workspace, WorkspaceColor,
│                         # Shell, TrashedAction, Run, RunStatus
├── ActionStore.swift     # @Published actions + trashedActions; JSON persistence
│                         # for actions.json and trash.json
├── WorkspaceStore.swift  # @Published workspaces; JSON persistence for workspaces.json
├── RunStore.swift        # @Published runs + logs (in-memory); process lifecycle
├── ProcessRunner.swift   # Shell execution: bash/zsh, profile loading, cwd, env, timeout
│
├── AppDelegate.swift     # NSStatusItem, NSPopover setup; store ownership;
│                         # openMainWindow(then:) helper; Notification.Name extensions
├── QuickrunApp.swift     # @main App; @NSApplicationDelegateAdaptor; theme binding
│
├── MainWindowView.swift  # NavigationSplitView — Tab enum + routing
├── PanelView.swift       # Menu bar popover: workspace filter, action tiles, logs section
│
├── WorkspacesView.swift  # Workspaces tab + WorkspaceFormView sheet
├── ActionsView.swift     # Actions tab: tile grid, create/edit/log sheets,
│                         # trash confirmation dialog
├── RunsView.swift        # Runs & Logs tab: run list + log viewer (fixed 220 pt left col)
├── LogsView.swift        # Reusable log viewer: auto-scroll, .textSelection(.enabled)
├── TrashView.swift       # Trash tab: restore / permanent delete / empty trash
├── ActionFormView.swift  # Create/edit action sheet: name, multiline command, shell picker,
│                         # profile toggle, folder picker, env vars, timeout
├── SettingsView.swift    # Settings tab: theme, login, export/import, reset
│
├── AppSettings.swift     # AppTheme enum (light/dark/system) + SettingsKey constants
├── Assets.xcassets/      # App icon
├── Info.plist            # LSUIElement = true; NSPrincipalClass = NSApplication
└── Quickrun.entitlements # com.apple.security.app-sandbox = false
```

---

## 4. Key implementation details

### Shell execution (ProcessRunner)

- **bash with profile**: `shopt -s expand_aliases` + explicit `source ~/.bash_profile` + `source ~/.bashrc` injected as preamble before the command.
- **zsh with profile**: `-l` flag + explicit `source ~/.bash_profile` preamble.
- **Without profile**: `["-c", command]` directly.
- Working directory set via `process.currentDirectoryURL`.
- Environment merged from `ProcessInfo.processInfo.environment` + action-specific vars.

### State ownership

- `ActionStore`, `RunStore`, `WorkspaceStore` are owned by `AppDelegate` and injected as `@EnvironmentObject` into both the popover and the main window.
- `@AppStorage` is used directly in views — never inside an `ObservableObject` (avoids "Publishing changes from within view updates" warnings).

### Cross-boundary navigation

- Panel → main window tab switch uses `NotificationCenter`:
  - `.quickrunOpenMainWindow` — open/focus main window
  - `.quickrunNavigateToRuns` — switch to Runs & Logs tab
- `openMainWindow(then:)` in `AppDelegate` posts the notification then activates the app; it finds the window by `styleMask.contains(.titled)`.

### Run status colors

Defined identically in both `ActionsView.ActionTile` and `PanelView.ActionTile`:

```swift
// tileBackground
if isRunning          → Color.green.opacity(0.12)
lastRun == .finished  → Color.blue.opacity(0.08)
lastRun == .error     → Color.orange.opacity(0.12)
default               → Color(NSColor.controlBackgroundColor)

// tileBorderColor
if isRunning          → Color.green.opacity(0.4)
lastRun == .finished  → Color.blue.opacity(0.35)
lastRun == .error     → Color.orange.opacity(0.4)
default               → Color(NSColor.separatorColor)
```

### Trash

- `actionStore.trash(_:)` moves an action to `trashedActions` (adds `trashedAt: Date`) and persists both lists.
- `actionStore.restore(_:)` reverses the move.
- `actionStore.permanentlyDelete(_:)` / `emptyTrash()` remove from trash only.
- Deletion from the tile always shows a `confirmationDialog` first.

### Export / Import

- Export bundle: `{ "actions": [...], "workspaces": [...] }` as JSON.
- On import: workspaces are deduplicated by `id` (existing ones are skipped); existing active actions are moved to trash before the imported ones are added.

---

## 5. Behaviour reminders

- **Mono-instance**: at most one run per action at a time. `RunStore.toggle(action:)` stops if running, starts if not.
- **App lifecycle**: `applicationShouldTerminateAfterLastWindowClosed` returns `false`; `applicationWillTerminate` calls `runStore.stopAll()`.
- **Panel height**: driven by `sizingOptions = .preferredContentSize`; scroll only enabled when `filteredActions.count > 10`.
- **Log auto-scroll**: `onChange(of: logText)` scrolls to bottom in `LogsView`.
- **Workspace badge in panel**: shown only in "All" filter mode (`filterRaw == "all"`); hidden when a workspace is selected.

---

## 6. What to avoid

- Do not sandbox the app — script execution requires user-level privileges.
- Do not put `@AppStorage` inside an `ObservableObject` — use it directly in views.
- Do not use `canBecomeMain` to find the main window — use `styleMask.contains(.titled)`.
- Do not use `ContentUnavailableView` — it requires macOS 14+.
- Do not use the two-parameter `onChange(of:perform:)` — it requires macOS 14+.
- Do not add multi-user, cloud sync, or remote execution.
- Do not use French or other non-English in code, comments, or user-facing strings.

---

## 7. When adding features

1. Check [spec.md](spec.md) for scope and data model.
2. Add new data fields to `Models.swift` with `Codable` conformance.
3. Add store methods to the appropriate `*Store.swift`.
4. Update views; keep panel tiles and main window tiles visually in sync.
5. Update `spec.md` and this file to reflect the change.
6. Commit with a clear English message.

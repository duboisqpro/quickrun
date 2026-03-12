# Quickrun — Technical documentation

> Architecture, data flow, and implementation details for contributors.

---

## Architecture overview

Quickrun is a hybrid **AppKit + SwiftUI** macOS app. AppKit handles the menu bar plumbing; SwiftUI drives all UI.

```
┌─────────────────────────────────────────────────────────┐
│  QuickrunApp (@main)                                    │
│    @NSApplicationDelegateAdaptor → AppDelegate          │
│    WindowGroup → MainWindowView                         │
└────────────────┬────────────────────────────────────────┘
                 │ owns stores
         ┌───────▼────────┐
         │   AppDelegate  │
         │  ┌───────────┐ │
         │  │ActionStore│ │──▶ actions.json
         │  │RunStore   │ │──▶ (in-memory)
         │  │Workspace  │ │
         │  │  Store    │ │──▶ workspaces.json
         │  └───────────┘ │          trash.json
         │  NSStatusItem  │
         │  NSPopover     │──▶ PanelView
         └───────┬────────┘
                 │ environmentObject injection
         ┌───────▼────────┐
         │ MainWindowView │──▶ WorkspacesView
         │ (NavigationSplit│──▶ ActionsView
         │  View)         │──▶ RunsView / LogsView
         │                │──▶ TrashView
         │                │──▶ SettingsView
         └────────────────┘
```

---

## Store layer

All stores are `ObservableObject` owned by `AppDelegate` and injected as `@EnvironmentObject` into every view.

### ActionStore

```swift
@Published var actions:        [Action]
@Published var trashedActions: [TrashedAction]
```

- `add(_:)` / `update(_:)` / `trash(_:)` — mutate `actions`, persist to `actions.json`.
- `restore(_:)` / `permanentlyDelete(_:)` / `emptyTrash()` — mutate `trashedActions`, persist to `trash.json`.
- Both arrays are persisted independently via `JSONEncoder`.

### RunStore

```swift
@Published var runs: [Run]
private(set) var logs: [UUID: String]
```

- `toggle(action:)` — starts or stops a run via `ProcessRunner`.
- `stopAll()` — called on `applicationWillTerminate`.
- `clearFinished()` — removes non-running runs from the list.
- `logs` is mutated directly (not `@Published`) — `objectWillChange.send()` is called manually before mutation to avoid double-publish issues.

### WorkspaceStore

```swift
@Published var workspaces: [Workspace]
```

Standard CRUD + `workspace(for id: UUID?) -> Workspace?` helper.

---

## Process execution

`ProcessRunner.run(action:onOutput:onTermination:)` builds and launches a `Foundation.Process`.

### Shell profile loading

```
bash + usesShellProfile:
  arguments = ["-c", """
    shopt -s expand_aliases
    [[ -f ~/.bash_profile ]] && source ~/.bash_profile
    [[ -f ~/.bashrc ]]       && source ~/.bashrc
    <command>
  """]

zsh + usesShellProfile:
  arguments = ["-l", "-c", """
    [[ -f ~/.bash_profile ]] && source ~/.bash_profile
    <command>
  """]

no profile:
  arguments = ["-c", "<command>"]
```

### Output capture

- `Pipe()` for stdout and stderr (merged into one stream).
- `fileHandleForReading.readabilityHandler` appends output to `RunStore.logs[run.id]`.
- `process.terminationHandler` updates `run.status` and calls `objectWillChange.send()` on the store.

---

## Navigation between panel and main window

The panel runs inside an `NSPopover` — it has no access to SwiftUI's `openWindow` environment action. Cross-boundary navigation uses `NotificationCenter`:

| Notification | Posted by | Observed by |
|---|---|---|
| `.quickrunOpenMainWindow` | `AppDelegate.openMainWindow()` | `QuickrunApp` → activates window |
| `.quickrunNavigateToRuns` | `PanelView` "See all" button | `MainWindowView` → sets `selectedTab = .runs` |

`AppDelegate.openMainWindow()` finds the window with `styleMask.contains(.titled)` (avoids matching the popover itself which has no title bar).

---

## Persistence

All JSON files live in `~/Library/Application Support/Quickrun/`.

| File | Type | Notes |
|---|---|---|
| `actions.json` | `[Action]` | Loaded on init, saved on every mutation |
| `workspaces.json` | `[Workspace]` | Loaded on init, saved on every mutation |
| `trash.json` | `[TrashedAction]` | Loaded on init, saved on every mutation |

Run history and logs are **in-memory only** — intentional, to avoid unbounded disk growth.

Write strategy: `data.write(to: url, options: .atomic)` — safe against partial writes.

---

## UI patterns

### Dynamic popover height

```swift
hosting.sizingOptions = .preferredContentSize
// No fixed height set on the popover — SwiftUI drives the size.
```

Scroll is enabled conditionally:

```swift
if filteredActions.count > 10 {
    ScrollView { grid }.frame(maxHeight: 300)
} else {
    grid   // panel grows naturally
}
```

### @AppStorage in views (not ObservableObject)

Putting `@AppStorage` inside an `ObservableObject` causes "Publishing changes from within view updates" console warnings. All preferences (`theme`, `launchAtLogin`, `panelWorkspaceFilter`) are declared directly in the views that use them.

### Log column layout

`RunsView` and `ActionLogSheet` use `GeometryReader + HStack` with a fixed 220 pt left column (not `HSplitView` or proportional sizing) to prevent date strings from wrapping.

### Tile status colors

Defined identically in `PanelView.ActionTile` and `ActionsView.ActionTile`:

```swift
var tileBackground: Color {
    if isRunning               { return .green.opacity(0.12)  }
    switch lastRun?.status {
    case .finished:              return .blue.opacity(0.08)
    case .error:                 return .orange.opacity(0.12)
    default:                     return Color(NSColor.controlBackgroundColor)
    }
}
```

---

## Adding a new file to the project

The `.pbxproj` is hand-crafted. When adding a new Swift file you must add entries in **three sections**:

1. **PBXBuildFile** — `AA…XX /* Foo.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA…YY; };`
2. **PBXFileReference** — `AA…YY /* Foo.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Foo.swift; sourceTree = "<group>"; };`
3. **PBXGroup children** — add `AA…YY /* Foo.swift */,` inside the `Quickrun` group.
4. **PBXSourcesBuildPhase files** — add `AA…XX /* Foo.swift in Sources */,`.

Use sequential hex IDs continuing from the last used (`AA0000000000000000000045` as of this writing).

---

## Deployment

- **Not sandboxed** — `Quickrun.entitlements`: `com.apple.security.app-sandbox = false`.
- **Dock-less** — `Info.plist`: `LSUIElement = YES`.
- **Code signing** — `CODE_SIGN_STYLE = Automatic` in build settings.
- **Bundle ID** — `com.quickrun.app`.
- **macOS 13+** — `MACOSX_DEPLOYMENT_TARGET = 13.0`.

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
- `move(from srcId: UUID, to dstId: UUID)` — reorders `actions` by resolving global indices from UUIDs; used by drag-and-drop in `ActionsView`.
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

- Standard CRUD + `workspace(for id: UUID?) -> Workspace?` helper.
- `move(from source: IndexSet, to destination: Int)` — reorders `workspaces`; used by drag-and-drop in `WorkspacesView`.

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
| `.quickrunNavigateToActions` | `WorkspacesView` workspace tile | `MainWindowView` → sets `selectedTab = .actions`; `ActionsView` → sets `filterWorkspaceId` |

`AppDelegate.openMainWindow()` defers the window search to the next run loop tick via `DispatchQueue.main.async` so the popover animation finishes before the main window is activated. It finds the main window with `styleMask.contains(.titled)` (avoids matching the popover itself which has no title bar).

---

## Drag-and-drop reordering

Both workspaces and actions support drag-and-drop reordering using the native SwiftUI APIs (macOS 13+):

```swift
tile
    .draggable(item.id.uuidString)          // String conforms to Transferable
    .dropDestination(for: String.self) { items, _ in
        // resolve source/destination, call store.move(...)
        return true
    } isTargeted: { targeted in
        dropTargetId = targeted ? item.id : nil
    }
```

Key design decisions:
- **`String` as transfer type** — `UUID.uuidString` is used as the draggable payload; no custom `Transferable` conformance needed.
- **`isTargeted` for visual feedback** — the drop target tile gets an accent-colored border and a `scaleEffect(1.02)`. No source dimming is tracked (avoids lifecycle bugs with the old `.onDrag`/`NSItemProvider` approach).
- **Global index resolution in `ActionStore.move`** — the action grid shows a filtered subset, but `move(from:to:)` works on the full `actions` array by resolving UUIDs to global indices. This ensures the persisted order is always correct regardless of the active filter.

---

## Workspace filtering

| Filter selection | Actions shown |
|---|---|
| "All" (nil) | Actions where `workspaceId == nil` (unassigned) |
| Workspace pill | Actions where `workspaceId == workspace.id` |

This applies in both `ActionsView` and `PanelView`. Actions are never shown in multiple filters simultaneously.

When a workspace filter is active and the user opens the **New Action** form, the workspace picker is pre-filled with the active filter's workspace.

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

### Consistent tile height

Action tiles always render a working-directory line, even when none is set (a non-breaking space is used as placeholder). This prevents tiles from varying in height depending on configuration.

---

## Building a distributable DMG

Use the included `build.sh` script at the project root:

```bash
./build.sh
```

This script:
1. Cleans the `build/` folder and any previous DMG.
2. Runs `xcodebuild` in Release configuration.
3. Creates a DMG with an `/Applications` symlink for drag-to-install.
4. Outputs `Quickrun.dmg` at the project root.

Without an Apple Developer certificate, Gatekeeper will block the app on other Macs. To bypass on the target machine:

```bash
xattr -cr /Applications/Quickrun.app
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

# Spec — macOS app « Quickrun »

## 1. Goal and audience

Build a macOS app that simplifies repetitive dev tasks as much as possible.

**Audience**: developers who often run the same scripts (servers, builds, watchers, one-off tasks) and want quick access from the menu bar, with visibility on logs and the ability to stop processes cleanly.

---

## 2. Features

### 2.1 Menu bar and panel

- **Location**: `bolt.circle.fill` icon in the macOS **menu bar** (top right, next to the clock).
- **Behaviour**: click the icon → a **panel** (NSPopover, transient) opens below the icon. Height is dynamic (fits content); scrollable if more than 10 actions.
- **Panel contents**:
  - **Header**: app name + "open main window" button (`arrow.up.right.square`).
  - **Workspace filter**: horizontal scrollable pill row — "All" + one pill per workspace (color dot + name). Selection persists via `@AppStorage`.
  - **Action tiles grid**: adaptive columns of small tiles. Each tile shows:
    - Action name (up to 2 lines).
    - Workspace badge (color dot + name) — only visible in "All" filter mode.
    - Background color indicates run status (see §2.4).
    - Tap = run/stop toggle.
  - **Logs section**: last 5 runs, each row expandable to show a 7-line log preview. "See all" button navigates to the Runs & Logs tab in the main window.

### 2.2 Main window

A **resizable window** with a `NavigationSplitView` sidebar + detail area. Tabs (in order):

| Tab | Icon | Description |
|-----|------|-------------|
| Workspaces | `folder.fill` | Create, edit, delete workspaces |
| Actions | `bolt.fill` | Tile grid of all actions — run/stop, create, edit, trash |
| Runs & Logs | `clock.fill` | Run history with full log viewer |
| Trash | `trash.fill` | Soft-deleted actions — restore or permanently delete |
| Settings | `gearshape.fill` | Appearance, startup, data, about |

Window opens from the panel; stays alive when closed (app lives in menu bar, `LSUIElement = true`).

### 2.3 Actions

An action wraps a shell script with the following properties:

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique identifier |
| `name` | String | Display label |
| `command` | String | Shell script content — may be multiline |
| `shell` | `bash` \| `zsh` | Shell used for execution |
| `usesShellProfile` | Bool | If true, sources `~/.bash_profile` + `~/.bashrc` (bash) or uses `-l` flag (zsh) before running the command |
| `workspaceId` | UUID? | Optional workspace this action belongs to |
| `workingDirectory` | String? | Working directory (chosen via folder picker); nil = app cwd |
| `environment` | `[String: String]` | Additional env vars injected before execution |
| `timeout` | TimeInterval? | Automatic kill after N seconds; nil = no timeout |

Actions are displayed as **advanced tiles** in the main window with: status indicator, shell badge, workspace badge, name, first line of command, working directory, last run status. Footer buttons: Run/Stop, Edit, Logs.

### 2.4 Run status and colors

| Status | Meaning | Tile background | Tile border |
|--------|---------|-----------------|-------------|
| Running | Process active | `green.opacity(0.12)` | `green.opacity(0.4)` |
| Finished | Exited with code 0 | `blue.opacity(0.08)` | `blue.opacity(0.35)` |
| Error | Exited with non-zero code | `orange.opacity(0.12)` | `orange.opacity(0.4)` |
| Killed | Stopped by user or timeout | neutral | system separator |
| No run yet | Never executed | neutral | system separator |

Colors are identical between the panel tiles and the main window tiles.

### 2.5 Workspaces

- A **workspace** groups related actions together (id, name, color).
- Colors available: blue, green, orange, pink, purple, red, teal, yellow.
- Actions can belong to zero or one workspace.
- Both the panel and the Actions tab support **filtering by workspace**.
- Managed in the dedicated **Workspaces tab** (create, edit, delete).

### 2.6 Trash

- Deleting an action moves it to the **trash** (soft delete) — requires confirmation dialog.
- From the **Trash tab**: restore an action (moves back to active list) or permanently delete it.
- "Empty Trash" button permanently deletes all trashed items.
- Trashed actions store `trashedAt: Date` for display ("deleted X ago").

### 2.7 History and logs

- Each action launch creates a **run** (id, actionId, actionName, startedAt, status, exitCode).
- Logs (stdout + stderr merged) are stored in memory per run.
- **Runs & Logs tab**: left column (220 pt fixed) lists runs; right column shows the full log with `.textSelection(.enabled)` and auto-scroll to bottom.
- **Action log sheet**: per-action run history accessible from the tile's "Logs" button.
- **Panel log preview**: last 7 lines of output, expandable per row.

### 2.8 Settings

| Setting | Description |
|---------|-------------|
| Theme | Light / Dark / System — applied via `preferredColorScheme` |
| Launch at login | `SMAppService.mainApp.register/unregister` |
| Export | Saves `{ actions, workspaces }` as JSON via `NSSavePanel` |
| Import | Loads JSON via `NSOpenPanel`; skips duplicate workspace IDs; existing actions moved to trash first |
| Reset | Permanently deletes all actions, workspaces, and trash — requires typing "RESET" to confirm |

---

## 3. Data model

```
Action          — id, name, command, shell, usesShellProfile, workspaceId?,
                  workingDirectory?, environment, timeout?
Workspace       — id, name, color (WorkspaceColor enum)
TrashedAction   — action (Action), trashedAt (Date)
Run             — id, actionId, actionName, startedAt, status (RunStatus), exitCode?
RunStatus       — running | finished | error | killed
```

Persistence (JSON files in `~/Library/Application Support/Quickrun/`):
- `actions.json` — active actions
- `workspaces.json` — workspaces
- `trash.json` — trashed actions

Run history and logs are **in-memory only** (reset on app quit).

---

## 4. User flow

```
Menu bar icon
  └─▶ Panel opens
        ├─ Workspace filter pill → filters tiles
        ├─ Action tile tap → run / stop toggle
        ├─ Log row expand → 7-line preview
        ├─ "See all" → opens main window on Runs & Logs tab
        └─ ↗ button → opens main window

Main window
  ├─ Workspaces tab → create / edit / delete workspaces
  ├─ Actions tab
  │    ├─ New Action → form sheet (name, command, shell, profile, cwd, env, timeout)
  │    ├─ Tile → Run/Stop, Edit, Logs
  │    └─ Tile × → confirmation → move to Trash
  ├─ Runs & Logs tab → select run → view full log
  ├─ Trash tab → restore or permanently delete
  └─ Settings tab → theme, login, export, import, reset
```

---

## 5. Persistence

- **Actions**: JSON in Application Support — survive app restart.
- **Workspaces**: JSON in Application Support — survive app restart.
- **Trash**: JSON in Application Support — survive app restart.
- **Run history / logs**: in-memory only — lost on quit.
- **Panel workspace filter**: `@AppStorage("panelWorkspaceFilter")` — survives panel close.
- **Theme preference**: `@AppStorage` — survives restart.

---

## 6. Constraints

- **Stack**: Swift/SwiftUI + AppKit (`NSStatusItem`, `NSPopover`, `NSHostingController`).
- **Not sandboxed**: `com.apple.security.app-sandbox = false` — required for arbitrary script execution.
- **Dock-less**: `LSUIElement = true` in Info.plist — app lives in menu bar only.
- **Mono-instance per action**: at most one running process per action at a time.
- **macOS 13+** minimum deployment target.
- **No multi-user, no cloud sync, no remote execution.**

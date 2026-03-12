# Quickrun — Functional documentation

> What the app does and how to use it.

---

## Overview

Quickrun lives in the macOS menu bar. Click the ⚡ icon to open a compact panel where you can run or stop any of your configured scripts in one click. The main window gives you full management: create actions, browse logs, manage workspaces, and configure the app.

---

## Menu bar panel

### Opening the panel

Click the `⚡` icon in the menu bar. The panel opens directly below and closes when you click outside it.

### Workspace filter

A horizontal row of pills lets you filter which actions are shown:

- **All** — shows every action regardless of workspace.
- **Workspace pill** — shows only actions belonging to that workspace.

Your filter selection is remembered between sessions.

### Action tiles

Each action is displayed as a small tile. Click a tile to **run** the script; click again to **stop** it.

The tile's background color reflects the last known state:

| Color | Meaning |
|-------|---------|
| Green tint | Currently running |
| Blue tint | Last run finished successfully |
| Orange tint | Last run ended with an error |
| Neutral | Killed by user, or never run |

When the "All" filter is active, a workspace badge (color dot + name) appears at the bottom of each tile.

### Logs section

The bottom of the panel shows the 5 most recent runs. Click any row to expand a 7-line preview of its output. Click **See all** to open the full Runs & Logs view in the main window.

### Open main window

Click the `↗` button in the panel header to open the main Quickrun window.

---

## Main window

The main window has five tabs in the left sidebar.

### Workspaces tab

Create logical groups to organise your actions.

- **New Workspace** — choose a name and a color.
- **Edit** — click the pencil icon on a row.
- **Delete** — swipe to delete or use the edit mode.

Workspaces are purely organisational — deleting a workspace does not delete its actions (they become unassigned).

### Actions tab

Your full action library displayed as an advanced tile grid.

**Each tile shows:**
- Status indicator (running / idle) + shell badge + workspace badge
- Action name and first line of command
- Working directory (if set)
- Last run status and time (or "Never run")

**Footer buttons:**
- **Run / Stop** — start or terminate the script.
- **Edit** — open the edit form.
- **Logs** — open a log sheet filtered to this action's runs.

**Creating an action** — click **New Action** and fill in:

| Field | Description |
|-------|-------------|
| Name | Display label shown on the tile |
| Command | Shell script content — multiline supported |
| Shell | `bash` or `zsh` |
| Load shell profile | Sources `~/.bash_profile` / `~/.bashrc` before running |
| Working directory | Folder picker; leave empty to inherit the app's cwd |
| Environment variables | Key=value pairs injected at runtime |
| Timeout | Auto-kill after N seconds; leave empty for no limit |
| Workspace | Assign to a workspace for filtering |

**Deleting an action** — click the `×` button on the tile. A confirmation dialog appears; the action moves to the **Trash** (not permanently deleted).

### Runs & Logs tab

- Left column: list of all runs (status color dot, action name, time, status label).
- Right column: full log output for the selected run. Text is selectable and copyable.
- **Clear** button removes all finished runs from the list.

### Trash tab

Actions that have been deleted land here.

- **Restore** — moves the action back to the active list.
- **×** — permanently deletes the action (cannot be undone).
- **Empty Trash** — permanently deletes everything in the trash.

### Settings tab

| Setting | Description |
|---------|-------------|
| Theme | Light, Dark, or System |
| Launch at login | Start Quickrun automatically when you log in |
| Export configuration | Saves all actions and workspaces to a JSON file |
| Import configuration | Loads actions and workspaces from a JSON file; existing actions are moved to trash first |
| Reset all data | Permanently deletes everything — requires typing `RESET` to confirm |

---

## Configuration file

Actions, workspaces, and trash are stored as plain JSON in:

```
~/Library/Application Support/Quickrun/
  actions.json
  workspaces.json
  trash.json
```

You can edit these files manually while the app is not running. Use **Settings → Export** to create a backup, and **Settings → Import** to restore.

---

## Run statuses

| Status | When it appears |
|--------|----------------|
| Running | Script is currently executing |
| Finished | Script exited with code 0 |
| Error | Script exited with a non-zero code |
| Killed | Stopped by the user (Run/Stop toggle) or by a timeout |

---

## Tips

- **Aliases and shell functions**: enable "Load shell profile" on the action to make your aliases and functions available.
- **Long-running processes**: Quickrun keeps the process alive even if you close the main window. The menu bar icon is always there to stop it.
- **Multiple projects**: use workspaces to group actions by project and switch context instantly with the filter pills.
- **Export before changes**: use Export before bulk-editing or resetting, so you can restore your configuration if needed.

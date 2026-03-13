<p align="center">
  <img src="docs/img/logo_title.png" width="320" alt="Quickrun" />
</p>

<p align="center">A native macOS menu bar app to run and manage shell scripts in one click.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license" />
</p>

<p align="center">
  <img src="docs/img/menubar.png" width="260" alt="Menu bar panel" />
  &nbsp;&nbsp;&nbsp;
  <img src="docs/img/app.png" width="520" alt="Main window — Actions tab" />
</p>

## Features

- **Menu bar access** — click the icon to open a compact panel with all your actions
- **Action tiles** — run or stop any script in one click, with live status color feedback
- **Workspaces** — group actions by project, filter them instantly, navigate from workspace tiles directly to filtered actions
- **Drag-and-drop ordering** — reorder both workspaces and actions by dragging tiles
- **Shell support** — bash or zsh, with optional profile loading (`~/.bash_profile`, `~/.bashrc`) — enabled by default
- **Advanced scripts** — multiline commands, custom working directory, environment variables, timeout
- **Run history & logs** — view output logs per run, with live scrolling
- **Trash** — deleted actions go to the trash and can be restored
- **Export / Import** — backup and restore your configuration as JSON
- **Launch at login** — optionally start Quickrun with macOS
- **Theme** — light, dark, or system

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (build only)

## Getting started

```bash
git clone https://github.com/YOUR_USERNAME/quickrun.git
cd quickrun
open Quickrun.xcodeproj
```

Build and run with `⌘R`. The app is **not sandboxed** so it can execute arbitrary shell scripts with your user privileges.

## Building a DMG

```bash
./build.sh
```

Produces `Quickrun.dmg` at the project root with a drag-to-`/Applications` installer layout.

## Configuration

Actions and workspaces are stored as JSON in:

```
~/Library/Application Support/Quickrun/actions.json
~/Library/Application Support/Quickrun/workspaces.json
~/Library/Application Support/Quickrun/trash.json
```

You can edit these files manually or use **Settings → Export / Import** to back up and restore your configuration.

## Project structure

```
Quickrun/
├── Models.swift          # Data models: Action, Workspace, Run, TrashedAction
├── ActionStore.swift     # Persistence for actions and trash
├── WorkspaceStore.swift  # Persistence for workspaces
├── RunStore.swift        # Process execution and run history
├── ProcessRunner.swift   # Shell process launcher
├── AppDelegate.swift     # NSStatusItem, NSPopover, store ownership
├── QuickrunApp.swift     # SwiftUI App entry point
├── MainWindowView.swift  # Root navigation (sidebar + tabs)
├── PanelView.swift       # Menu bar popover panel
├── ActionsView.swift     # Actions tab (tile grid)
├── WorkspacesView.swift  # Workspaces tab (tile grid)
├── TrashView.swift       # Trash tab
├── RunsView.swift        # Runs & Logs tab
├── LogsView.swift        # Log viewer
├── ActionFormView.swift  # Create / edit action sheet
├── SettingsView.swift    # Settings tab
└── AppSettings.swift     # Theme enum and settings keys
```

## Documentation

- [Functional documentation](docs/functional.md) — how to use the app (panel, actions, workspaces, logs, settings)
- [Technical documentation](docs/technical.md) — architecture, stores, process execution, drag-and-drop, UI patterns, pbxproj

## License

MIT — see [LICENSE](LICENSE).

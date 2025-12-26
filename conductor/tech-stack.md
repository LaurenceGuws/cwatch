# Tech Stack - CWatch

## Frontend / Core
- **Language:** Dart
- **Framework:** Flutter (Targeting Desktop, Mobile, and Web)
- **State Management:** (Inferred) Provider/ChangeNotifier or Built-in Flutter State.

## Infrastructure & Connectivity
- **SSH/SFTP (Built-in):** `dartssh2` - Pure Dart implementation for vault-backed connectivity.
- **SSH/SFTP (Native):** Interop with system `ssh` and `scp` CLI tools.
- **Terminal Emulation:** `xterm` (Patched in `packages/xterm_patched`) for stable selection/scrolling.
- **Local PTY:** `flutter_pty` for local terminal sessions.

## Specialized Components
- **Data Visualization:** `fl_chart` for CPU, RAM, and Disk monitoring dashboards.
- **File Editing:** `flutter_code_editor` + `flutter_highlight` for the remote file editor.
- **System Integration:**
    - `window_manager` for advanced desktop window control.
    - `path_provider` & `file_picker` for local filesystem access.
    - `desktop_drop`, `super_drag_and_drop` for interoperability.
- **CLI Interop:** Integration with system tools including `docker`, `kubectl`, `ssh`, etc.

## UI & Assets
- **Design System:** Refined Material Design 3.
- **Typography:** Nerd Fonts (`IosevkaTermNF`, `JetBrainsMono Nerd Font`) for technical iconography.

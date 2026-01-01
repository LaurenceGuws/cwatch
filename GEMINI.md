# CWatch - Project Context for Gemini

## 1. Project Overview
**CWatch** is a cross-platform Flutter application designed for power users to manage servers, Docker resources, and remote files. It features built-in SSH connectivity, terminal emulation, and resource monitoring dashboards.

**Key Features:**
- **Docker Management:** Engine picker, context dashboards, stats, logs, and container shell.
- **Server Management:** SSH connectivity, resource monitoring (CPU/RAM/Disk), process trees, and remote file exploration.
- **Terminals:** Local and SSH-based PTY sessions using a patched `xterm` library.
- **Settings:** SSH vault/keys, themes, and application preferences.

## 2. Architecture & Directory Structure
The project follows a feature-based architecture with a clear separation of concerns:

- **`lib/`**: Main source code.
    - **`main.dart`**: Entry point.
    - **`core/`**: Application scaffolding, navigation, workspace state, and global services.
    - **`modules/`**: Feature-specific code. Each module (e.g., `docker`, `servers`, `settings`) contains its own views, widgets, and logic.
    - **`services/`**: Business logic and data access layers (e.g., `ssh`, `docker`, `filesystem`).
    - **`models/`**: Data models and state classes.
    - **`shared/`**: Reusable UI components, widgets, themes, and utilities used across modules.
- **`packages/`**: Contains vendored/patched packages (`flutter_code_editor_patched`, `xterm_patched`) used via `dependency_overrides`.
- **`conductor/`**: Project management documentation, guidelines, and track plans.
- **`assets/`**: Fonts (Nerd Fonts), images, and themes.

## 3. Development Workflow

### Commands
- **Install Dependencies:** `flutter pub get`
- **Run App:** `flutter run -d <device>` (Supports desktop, web, mobile)
- **Analyze Code:** `flutter analyze` (Run before every commit)
- **Run Tests:** `flutter test` (Use `--coverage` for coverage reports)
  - *Note:* While the standard command exists, the project currently enforces no automated test coverage requirements. Do not add tests unless explicitly requested.

### Coding Standards
- **Style:** Follow standard Flutter conventions (2-space indentation, trailing commas).
- **Formatting:** Use `flutter format`.
- **Naming:** PascalCase for classes (`ServerExplorer`), camelCase for members (`connectToHost`), snake_case for files (`server_explorer.dart`).
- **Imports:** Order: Dart SDK -> Third-party packages -> Project files.

### Operational Rules (Critical)
- **Commits:** **Manual commits only.** Do not perform automatic commits. You must propose changes and ask the user to commit, or strictly follow the user's request if asked to commit.
- **Git History:** Never modify git history (no force-push, rebase, or amend) unless explicitly instructed.
- **Testing:** Do not add or run tests unless explicitly requested by the user.

## 4. Tech Stack
- **Framework:** Flutter (Dart)
- **State Management:** Provider / ChangeNotifier (Inferred from codebase patterns).
- **Key Packages:**
    - `dartssh2`: Pure Dart SSH implementation.
    - `xterm`: Terminal emulation (custom patched version).
    - `fl_chart`: Charts and graphs.
    - `window_manager`: Desktop window control.
    - `flutter_code_editor` / `highlight`: Code editing and syntax highlighting.

## 5. Design & Product Guidelines
- **Visual Identity:** Refined Material Design 3.
    - **Density:** High information density for power users. Reduce margins and padding.
    - **Separation:** Use tonal variations rather than heavy borders or shadows.
    - **Typography:** Use Nerd Fonts (`IosevkaTermNF`, `JetBrainsMono Nerd Font`) for technical data and icons.
- **UX:**
    - **Context:** Use right-click context menus and adaptive toolbars.
    - **Input:** Optimize for keyboard/mouse on desktop and touch gestures on mobile.

## 6. Agent Tools & Context
- **Conductor:** If the user mentions a "plan", refer to `conductor/tracks.md` or specific track plans in `conductor/tracks/`.
- **DTD/MCP:** The project supports Dart Tooling Daemon (DTD) for deep inspection. Refer to `AGENTS.md` for specific tool usage if needed (e.g., `get_widget_tree`).

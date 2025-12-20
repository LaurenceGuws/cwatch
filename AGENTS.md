# Repository Guidelines

## Project Structure & Module Organization
`lib/` hosts Flutter source (entry points, providers, UI widgets) while `test/` mirrors that layout for unit and widget coverage. Platform shells live under `android/`, `ios/`, `linux/`, `macos/`, `windows/`, and `web/`; treat them as generated except when editing native integrations. Shared assets, configs, and localization bundles sit alongside `pubspec.yaml`. Keep feature-specific code inside `lib/modules/<feature>` with shared utilities in `lib/core`.

## Build, Test, and Development Commands
- `flutter pub get` – install or refresh Dart dependencies declared in `pubspec.yaml`.
- `flutter run -d <device>` – launch the app on a simulator, emulator, or browser for quick manual verification.
- `flutter analyze` – static analysis; run before every commit to catch formatting and API misuse.
- `flutter test` – execute all unit/widget tests under `test/`; use `--coverage` when validating coverage thresholds.

## Coding Style & Naming Conventions
Follow Flutter defaults: 2-space indentation, trailing commas to enable formatter-friendly diffs, and `flutter format` (or IDE auto-format) on touched files. Use PascalCase for classes/widgets (`ServerExplorerPane`), camelCase for methods and fields, and snake_case for file names (`server_explorer_pane.dart`). Organize imports: Dart SDK, third-party packages, project files. Keep widgets small; extract sub-widgets when build methods exceed ~100 lines.

## Testing Guidelines
There are no tests yet; do not add or run tests unless the user explicitly asks.

## MCP (Dart Tooling Daemon) Usage
Use DTD-backed tools for runtime inspection (widget tree, runtime errors, hot reload/restart).

Setup steps:
- Ensure the repo is added as a DTD root: `add_roots` with `file:///.../cwatch`.
- Start a tooling daemon and keep it running:
  - `dart tooling-daemon --unrestricted --port 0`
  - Copy the `ws://...` URI it prints.
- Run the app with DTD enabled:
  - `flutter run --print-dtd --machine -d <device>`
  - Copy the `app.dtd` `ws://...` URI from the machine output.
- Connect to the app DTD URI via `connect_dart_tooling_daemon`.

Notes:
- DTD requires a compatible Dart/Flutter SDK; if connections fail, update the SDK.
- If a daemon is already connected, stop or restart it before reconnecting.
- When using scroll or widget inspection tools, ensure the target tab/view is visible.

## MCP Tools Catalog

### code-graph-rag
Use for structural code intelligence across the repo (indexing, semantic search,
relationship graph, hotspots, and clone detection).
- First-time setup: run `index` or `clean_index` on the repo root.
- Large repos: prefer `batch_index` to avoid timeouts.
- Common flows:
  - `semantic_search` or `query` to locate concepts.
  - `list_file_entities` → `list_entity_relationships` for exact structure.
  - `analyze_code_impact` before refactors.
  - `analyze_hotspots` or `jscpd_detect_clones` for risk/duplication.

### dart
Use for Dart/Flutter runtime inspection, hot reload/restart, and analyzer actions
after connecting to a live DTD session.
- Setup: see “MCP (Dart Tooling Daemon) Usage” above.
- Common flows:
  - `get_widget_tree` / `get_selected_widget` for UI inspection.
  - `get_runtime_errors` after hot reload.
  - `flutter_driver` for targeted UI actions.

### java-filesystem
Use for file operations when the standard shell tools are not available or when
line-based edits are needed.
- Preferred tools:
  - `readFile`, `editFile`, `writeFile`, `searchFiles`, `grepFiles`.
  - `executeBash` for safe shell commands (no destructive ops).
  - `fetchWebpage` for simple HTML/text retrieval.

### javadoc
Use for Java API discovery and documentation lookup when working with JVM code.
- `search_classes` / `search_methods` for discovery.
- `get_class_details` for full API info.

### playwright
Use for browser automation and UI verification.
- `browser_navigate` + `browser_snapshot` for state capture.
- `browser_click` / `browser_type` / `browser_select_option` for interactions.

## Commit & Pull Request Guidelines
Commit subjects follow the imperative mood (`Add terminal session recorder`) and stay under ~70 characters. Reference issues in the body when applicable. Pull requests must include: concise summary, screenshots or screen recordings for UI changes, reproducible test steps (`flutter test` output), and notes on platform-specific impacts. Request review from module owners (listed in CODEOWNERS when available) before merging.

## Git Usage
Do not run any `git` command unless the user explicitly requests it.

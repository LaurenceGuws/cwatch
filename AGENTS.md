# Repository Guidelines

## Project Structure & Module Organization
`lib/` hosts the Flutter source (entry points, providers, UI widgets) while `test/` mirrors that layout for unit and widget coverage. Platform shells live under `android/`, `ios/`, `linux/`, `macos/`, `windows/`, and `web/`; treat them as generated except when editing native integrations. Shared assets, configs, and localization bundles sit alongside `pubspec.yaml`. Keep feature-specific code inside `lib/modules/<feature>` with shared utilities in `lib/core`.

## Build, Test, and Development Commands
- `flutter pub get` – install or refresh Dart dependencies declared in `pubspec.yaml`.
- `flutter run -d <device>` – launch the app on a simulator, emulator, or browser for quick manual verification.
- `flutter analyze` – static analysis; run before every commit to catch formatting and API misuse.
- `flutter test` – execute all unit/widget tests under `test/`; use `--coverage` when validating coverage thresholds.

## Coding Style & Naming Conventions
Follow Flutter defaults: 2-space indentation, trailing commas to enable formatter-friendly diffs, and `flutter format` (or IDE auto-format) on touched files. Use PascalCase for classes/widgets (`ServerExplorerPane`), camelCase for methods and fields, and snake_case for file names (`server_explorer_pane.dart`). Organize imports: Dart SDK, third-party packages, project files. Keep widgets small; extract sub-widgets when build methods exceed ~100 lines.

## Testing Guidelines
Use `package:flutter_test` for widgets and `package:mocktail` or similar for mocks. Co-locate tests under `test/<module>/<file>_test.dart` and mirror production file names. Ensure critical flows (server discovery, terminal execution, file operations) have coverage and add golden tests for complex UI fragments. Run `flutter test --coverage` in CI; target at least 70% on core modules.

## Commit & Pull Request Guidelines
Commit subjects follow the imperative mood (`Add terminal session recorder`) and stay under ~70 characters. Reference issues in the body when applicable. Pull requests must include: concise summary, screenshots or screen recordings for UI changes, reproducible test steps (`flutter test` output), and notes on platform-specific impacts. Request review from module owners (listed in CODEOWNERS when available) before merging.

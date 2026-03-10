# Repository Guidelines

## Project Structure & Module Organization
CWatch is a Flutter desktop app with a tabbed workspace shell. Core areas:
- `lib/core/` app bootstrap, navigation shell, and workspace/tab persistence.
- `lib/modules/` feature modules: `servers/`, `docker/`, `kubernetes/`, `wsl/` (Windows only), `debug_logs/`, `settings/`.
- `lib/services/ssh/` SSH backends (process vs built‑in), vault/key handling, host key verification, SFTP.
- `lib/shared/views/shared/tabs/` terminal/editor/file explorer tabs used across modules.
- `assets/` terminal/editor theme presets and media (declared in `pubspec.yaml`).
- `packages/` patched deps: `xterm_patched`, `flutter_code_editor_patched`.

## Build, Test, and Development Commands
- `flutter pub get` install dependencies.
- `flutter run -d <device>` run locally on a device/emulator.
- `flutter analyze` required after each change (linting via `analysis_options.yaml`).
- `flutter test` run unit/widget tests; add `--coverage` to mirror CI.
- `flutter build <platform>` build release artifacts (e.g., `flutter build macos`).

## Coding Style & Naming Conventions
- 2‑space indentation; prefer trailing commas in widget trees.
- Import order: SDK → third‑party → project.
- Use snake_case for Dart files and tests (`remote_shell_service.dart`, `terminal_tab_test.dart`).
- Keep service logic under `lib/services/` and UI under `lib/modules/` or `lib/shared/`.

## Testing Guidelines
- Framework: `flutter_test`.
- Place tests under `test/` with `*_test.dart` naming.
- Add regression coverage for SSH terminal/editor flows and Docker/K8s dashboards when changing those paths.

## Commit & Pull Request Guidelines
- Default: do not commit until tests/analyze have been run and the user explicitly approves.
- If the user explicitly says to commit, treat that instruction as approval and comply without blocking on additional approval.
- Work on `main` by default. Create a feature branch only when the task is large enough that isolated branch management materially reduces risk or review cost.
- If you create a feature branch, own it end-to-end: branch from current `main`, keep commits coherent, merge back into `main` after validation, and delete the branch once merged.
- Once approved to commit, prefer incremental commits per logical step so each change is easy to trace and bisect for regressions.
- Prefer small, atomic commits scoped to one change theme (for example: one bug fix, one refactor, one test update).
- Include tests/analyze updates in the same commit when they are directly tied to that code change.
- Commit messages in this repo are short, lowercase, and descriptive (e.g., “k8s fixed”).
- PRs should include: change summary, `flutter analyze`/`flutter test` output, and screenshots for UI changes.

## Configuration & Assets
- Update `pubspec.yaml` when adding assets or fonts; keep theme presets in `assets/themes/`.
- Patched packages in `packages/` should stay in sync with upstream; document deltas in PR notes.

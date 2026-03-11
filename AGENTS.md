# Repository Guidelines

## Project Structure & Module Organization
CWatch is a Flutter desktop app with a tabbed workspace shell.

Current top-level structure:
- `lib/view/`: Flutter UI, feature workspaces, shared tabs, app shell/navigation.
- `lib/controller/`: controllers, adapters, workspace orchestration, DI bindings, repositories.
- `lib/model/`: data models, domain services, infrastructure services, shared non-UI utilities.
- `assets/`: terminal/editor theme presets and media declared in `pubspec.yaml`.
- `packages/`: patched dependencies: `xterm_patched`, `flutter_code_editor_patched`.
- `docs/`: active rewrite planning and analysis documents.

Important: the current `view/controller/model` split is not a clean architecture boundary yet. When making documentation or review statements, describe it as the current implementation layout, not as an enforced dependency model.

## Build, Test, and Development Commands
- `flutter pub get` install dependencies.
- `flutter run -d <device>` run locally on a device/emulator.
- `flutter analyze` required after code changes.
- `flutter test` run unit/widget tests; add `--coverage` when needed.
- `flutter build <platform>` build release artifacts (for example `flutter build macos`).

## Coding Style & Naming Conventions
- 2-space indentation; prefer trailing commas in widget trees.
- Import order: SDK, third-party, project.
- Use snake_case for Dart files and tests (`remote_shell_service.dart`, `terminal_tab_test.dart`).
- Keep UI under `lib/view/`, workflow/controller code under `lib/controller/`, and non-UI service/model code under `lib/model/` unless the rewrite plan explicitly changes that boundary.
- Avoid introducing new cross-layer shortcuts that make `model -> view` or `model -> controller` coupling worse.

## Documentation Expectations
- Keep `README.md`, `AGENTS.md`, and active planning docs aligned with the codebase.
- Use `docs/rewrite_foundations.md` as the high-level source for rewrite scope and sequencing.
- If a document is speculative, proposal-only, or tied to a future migration, label it clearly.
- Prefer updating stale docs over leaving contradictory architecture claims in place.

## Testing Guidelines
- Framework: `flutter_test`.
- Place tests under `test/` with `*_test.dart` naming.
- Add regression coverage for SSH terminal/editor flows, file explorer flows, and Docker/Kubernetes dashboards when changing those paths.
- For structural cleanup, favor characterization tests before behavior changes.

## Commit & Pull Request Guidelines
- Default: do not commit until tests/analyze have been run and the user explicitly approves.
- If the user explicitly says to commit, treat that instruction as approval and comply without blocking on additional approval.
- Work on `main` by default. Create a feature branch only when the task is large enough that isolated branch management materially reduces risk or review cost.
- If you create a feature branch, own it end-to-end: branch from current `main`, keep commits coherent, merge back into `main` after validation, and delete the branch once merged.
- Once approved to commit, prefer incremental commits per logical step so each change is easy to trace and bisect for regressions.
- Prefer small, atomic commits scoped to one change theme.
- Include test/analyze results in the same commit when they are directly tied to the code change.
- Commit messages in this repo are short, lowercase, and descriptive.
- PRs should include: change summary, validation output, and screenshots for UI changes.

## Configuration & Assets
- Update `pubspec.yaml` when adding assets or fonts; keep theme presets in `assets/themes/`.
- Patched packages in `packages/` should stay in sync with upstream; document deltas in PR notes.

## Rewrite Context
The repo has already completed major first-pass work in:
- dependency direction and layer boundaries
- composition root and service ownership
- settings/state separation
- vertical slice decomposition
- infrastructure boundary cleanup
- test seam creation
- product polish on major shared shell surfaces

Current fresh-review hotspot order is:
1. feature-local settings workflow reevaluation only if fresh evidence reopens it
2. SSH runtime/feature integration reevaluation only if fresh evidence reopens it
3. file-operation flow reevaluation only if fresh evidence reopens it

Use the current-state review docs as the handover source of truth before reopening older rewrite priorities:
- `docs/current_code_smell_review.md`
- `docs/settings_workflow_reevaluation_todo.md`
- `docs/workspace_shell_hosting_hotspot_todo.md`
- `docs/runtime_composition_hotspot_todo.md`
- `docs/settings_hotspot_todo.md`
- `docs/ui_adapter_surface_hotspot_todo.md`

Checkpointed design baselines that should be treated as current enforced state unless new evidence reopens them:
- Docker feature decomposition
- SSH runtime support decomposition
- SSH shell-factory/runtime-cache simplification
- file-operation UI deduplication
- config metadata single-source-of-truth cleanup
- UI-adapter surface reduction
- runtime/composition ownership cleanup
- workspace-shell hosting reuse
- theme/token decomposition
- StructuredDataTable engine projection decomposition
- settings mutation ownership cleanup

Use the planning docs to deepen one focus area at a time instead of attempting broad rewrite-by-replacement.

## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used. Each entry includes a name, description, and file path so you can open the source for full instructions when using a specific skill.
### Available skills
- skill-creator: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Codex's capabilities with specialized knowledge, workflows, or tool integrations. (file: /home/home/.codex/skills/.system/skill-creator/SKILL.md)
- skill-installer: Install Codex skills into $CODEX_HOME/skills from a curated list or a GitHub repo path. Use when a user asks to list installable skills, install a curated skill, or install a skill from another repo (including private repos). (file: /home/home/.codex/skills/.system/skill-installer/SKILL.md)
### How to use skills
- Discovery: The list above is the skills available in this session (name + description + file path). Skill bodies live on disk at the listed paths.
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description shown above, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
- Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
- How to use a skill (progressive disclosure):
  1) After deciding to use a skill, open its `SKILL.md`. Read only enough to follow the workflow.
  2) When `SKILL.md` references relative paths (for example `scripts/foo.py`), resolve them relative to the skill directory listed above first, and only consider other paths if needed.
  3) If `SKILL.md` points to extra folders such as `references/`, load only the specific files needed for the request; don't bulk-load everything.
  4) If `scripts/` exist, prefer running or patching them instead of retyping large code blocks.
  5) If `assets/` or templates exist, reuse them instead of recreating from scratch.
- Coordination and sequencing:
  - If multiple skills apply, choose the minimal set that covers the request and state the order you'll use them.
  - Announce which skill(s) you're using and why (one short line). If you skip an obvious skill, say why.
- Context hygiene:
  - Keep context small: summarize long sections instead of pasting them; only load extra files when needed.
  - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless you're blocked.
  - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
- Safety and fallback: If a skill can't be applied cleanly (missing files, unclear instructions), state the issue, pick the next-best approach, and continue.

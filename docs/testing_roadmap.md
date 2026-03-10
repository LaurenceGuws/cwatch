# Testing Roadmap

Status: active
Purpose: define the minimum testing strategy needed to support the structural cleanup safely.

## Current State
- The repository currently has no Dart tests under `test/`.
- A rewrite without characterization coverage will be high-risk.
- The first goal is not broad coverage. The first goal is to capture current behavior around the highest-risk workflows.

## Current Best Entry Point

The first tests should target the new shared persistence seams, not large feature widgets.

Why:
- the recent rewrite work created explicit boundaries that are now worth locking down
- these seams are shared across multiple features
- they can be tested without live SSH, Docker, Kubernetes, or Flutter widget harnesses

The highest-value first seams are:
- `WorkspaceRootController`
- `WorkspacePersistence<T>`
- grouped `AppSettings` serialization for extracted preference/config sections

This gives the rewrite a regression floor around:
- workspace snapshot persistence
- grouped settings persistence
- migration-seed fallback boundaries that still exist on purpose

## Testing Strategy For Cleanup Work

### Phase 1: characterization coverage
Add tests that describe current behavior before structural changes in these areas:
- workspace persistence
- SSH terminal session lifecycle
- remote file explorer navigation and operations
- Docker context/container parsing and state shaping
- Kubernetes dashboard/resource shaping

### Phase 2: seam-level service tests
After introducing cleaner boundaries, add focused tests around:
- command execution gateways
- parsing adapters
- feature coordinators/view-models
- settings/state split logic

### Phase 3: targeted widget tests
Add widget coverage for the smallest number of user-critical surfaces:
- file explorer list interactions
- terminal/editor shell surfaces
- key dialogs that coordinate destructive or persistence-heavy actions

## Initial Backlog

### Priority 1
1. `workspace_root_controller_test.dart`
   - loads persisted workspaces from `workspaces.json`
   - falls back to legacy embedded workspace data from `AppSettings` when dedicated workspace storage is empty
   - updates and saves the dedicated workspace root without touching feature views

2. `workspace_persistence_test.dart`
   - persist/restore behavior through `WorkspaceRootController`
   - signature comparisons
   - pending-save behavior
   - duplicate persist suppression for identical workspace signatures

3. `app_settings_serialization_test.dart`
   - grouped preference/config sections serialize in the new shape:
     - `shellPreferences`
     - `editorPreferences`
     - `terminalPreferences`
     - `explorerPreferences`
     - `sshPreferences`
     - `kubernetesPreferences`
     - `dockerPreferences`
   - obsolete flat preference/config keys are not written anymore
   - grouped sections round-trip through `AppSettings.fromJson` / `toJson`

4. `terminal_session_controller_test.dart`
   - start/write/resize/reset/dispose
   - output subscription behavior
   - error propagation

5. `explorer_ops_test.dart`
   - path loading and normalization
   - navigation history
   - search behavior
   - selection state changes

6. `path_loading_service_test.dart`
   - cached load vs forced load
   - list/search behavior
   - malformed/partial results

7. `file_editing_service_test.dart`
   - open/save/sync flows
   - cache behavior
   - merge conflict handling

### Priority 2
8. `docker_client_service_test.dart`
   - context parsing
   - container parsing
   - error handling and timeout behavior

9. `kubernetes_dashboard_service_test.dart`
   - CLI/API data shaping
   - warning collection
   - empty/error snapshot behavior

10. `resource_parser_test.dart`
   - CPU, memory, disk, processes, network parsing
   - malformed input handling

11. `explorer_trash_manager_test.dart`
   - move/restore/empty behavior
   - restore event handling

### Priority 3
12. `file_explorer_tab_test.dart`
    - loading/error/render states
    - search activation and key interaction

13. `settings_split_characterization_test.dart`
    - keep only if a later migration introduces non-trivial compatibility or cross-file settings migration rules

## First Executable Batch

### Task 13.1: scope characterization tests for persistence seams
Status: completed

What this task checked:
- whether the first test batch should start in feature UI
- or at the shared persistence contracts created by the rewrite

Conclusion:
- the first useful coverage should target persistence seams, not widgets
- the best first batch is:
  - `workspace_root_controller_test.dart`
  - `workspace_persistence_test.dart`
  - `app_settings_serialization_test.dart`

Why this is the right first batch:
- it locks down the new root boundaries before more rewrite layers build on them
- it validates shared behavior used by multiple modules
- it avoids brittle widget-heavy tests before the structural cleanup settles

Done definition:
- the first characterization batch is explicitly scoped to shared persistence seams
- each target test file has a concrete behavior list
- the next implementation step can start with test code instead of more planning

## Test Organization

Recommended structure:

```text
test/
  core/
  controller/
  model/
  services_infra/
  widgets/
```

Keep tests close to the layer they validate, but favor business behavior over implementation detail.

## Rules For Rewrite Work
- Add characterization tests before changing high-risk behavior.
- When fixing a bug discovered during cleanup, add the regression test in the same change when practical.
- Prefer fast fakes over heavyweight integration harnesses for early coverage.
- Keep tests deterministic; avoid depending on live SSH, Docker, or Kubernetes environments in routine test runs.

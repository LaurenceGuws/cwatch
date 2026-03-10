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

### Task 13.2: add `workspace_root_controller_test.dart`
Status: completed

What landed:
- [workspace_root_controller_test.dart](/home/home/personal/cwatch/test/model/services_infra/settings/workspace_root_controller_test.dart)

Coverage added:
- loads persisted workspaces from dedicated workspace storage
- falls back to legacy embedded workspace data from `AppSettings`
- saves updates through the dedicated workspace root
- coalesces concurrent `ensureLoaded()` calls into one storage load

Why this was first:
- it locks down the root workspace persistence seam shared by multiple modules
- it validates the legacy-to-dedicated workspace boundary without involving feature UI
- it gives the rewrite a concrete regression floor around the new `workspaces.json` flow

Verification:
- `flutter test test/model/services_infra/settings/workspace_root_controller_test.dart`
- `flutter analyze`

### Task 13.3: add `workspace_persistence_test.dart`
Status: completed

What landed:
- [workspace_persistence_test.dart](/home/home/personal/cwatch/test/controller/core/workspace/workspace_persistence_test.dart)
- [workspace_root_controller.dart](/home/home/personal/cwatch/lib/model/services_infra/settings/workspace_root_controller.dart) now short-circuits `ensureLoaded()` once the controller is already loaded

Coverage added:
- `read()` / `load()` use the configured root mapping
- `shouldRestore()` flips after `markRestored()` for a matching signature
- `persist()` writes through the root controller
- duplicate signatures are suppressed
- `markRestored()` seeds duplicate suppression until the signature changes
- `persistIfPending()` currently does nothing when no save is pending

Why this mattered:
- the new test exposed a real bug in `WorkspaceRootController.ensureLoaded()`
- repeated `ensureLoaded()` calls were reloading from storage after the controller was already loaded
- that could discard in-memory updates before the next explicit save path completed

Verification:
- `flutter test test/controller/core/workspace/workspace_persistence_test.dart`
- `flutter analyze`

### Task 13.4: add `app_settings_serialization_test.dart`
Status: completed

What landed:
- [app_settings_serialization_test.dart](/home/home/personal/cwatch/test/model/models/app_settings_serialization_test.dart)

Coverage added:
- grouped preference/config sections serialize under the new nested keys
- obsolete flat preference/config keys are not written anymore
- grouped sections round-trip through `AppSettings.fromJson` / `toJson`

Why this matters:
- it locks down the cleanup away from the old root-level settings sprawl
- it makes regressions toward flat fallback-style persistence obvious
- it validates the grouped contract without requiring UI or storage integration tests

Verification:
- `flutter test test/model/models/app_settings_serialization_test.dart`
- `flutter analyze`

### Task 13.5: re-scope after the first characterization batch
Status: completed

What this re-scope checked:
- whether the next test should move into:
  - file explorer behavior
  - Docker parsing
  - Kubernetes dashboard shaping
  - terminal lifecycle

Conclusion:
- the next best test hotspot is `explorer_ops_test.dart`

Why this is next:
- `ExplorerOps` is now on a cleaner non-widget seam after the ownership cleanup
- it contains high-risk interactive behavior:
  - path loading
  - search activation/reset
  - path history mutation
  - selection clearing
  - notification timing
- it can be tested with a narrow fake `PathLoadingService`
- it avoids the heavier process/API mocking required by Docker and Kubernetes service tests

What should wait:
- `docker_client_service_test.dart`
  - still valuable, but requires process-runner-driven parsing tests
- `kubernetes_dashboard_service_test.dart`
  - still valuable, but broader and more data-heavy
- `terminal_session_controller_test.dart`
  - still valuable, but likely tied to more lifecycle/setup complexity than `ExplorerOps`

Next executable batch:
- `Task 13.6`: add `explorer_ops_test.dart`

Done definition:
- the next test target is selected from current seam value, not backlog order alone
- the roadmap explicitly explains why `ExplorerOps` comes before Docker/Kubernetes parsing

### Task 13.6: add `explorer_ops_test.dart`
Status: completed

What landed:
- [explorer_ops_test.dart](/home/home/personal/cwatch/test/model/services/explorer_ops_test.dart)

Coverage added:
- successful path loading updates entries, path history, selection state, and cached local edits
- load errors surface without clobbering existing entries
- search activation path clears stale selection and handles streamed-entry dedupe before final replacement
- empty search query reloads the current path instead of running a search request
- prefetch populates path history once and routes failures through `onPrefetchError`

Why this matters:
- it locks down the non-widget explorer behavior after the explorer ownership cleanup
- it covers a high-risk user workflow without dragging in Flutter widget harnesses
- it gives the next explorer refactors a regression floor around state mutation and notification behavior

Verification:
- `flutter test test/model/services/explorer_ops_test.dart`
- `flutter analyze`

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

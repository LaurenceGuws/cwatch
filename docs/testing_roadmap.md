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

For SSH, Docker, and Kubernetes paths, characterization tests should assume capability variance:
- missing system CLIs are expected on some client machines
- missing CLIs should degrade feature availability, not make the app behave as if startup failed
- tests should prefer "capability unavailable" behavior over "panic if tool is absent"
- batteries-included paths such as built-in SSH support remain part of the intended product direction

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
   - missing Docker CLI is treated as capability unavailability, not app-fatal failure

9. `kubernetes_dashboard_service_test.dart`
   - CLI/API data shaping
   - warning collection
   - empty/error snapshot behavior
   - missing CLI or API access degrades to warnings/empty states that UI layers can surface cleanly

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
  - still valuable, but requires process-runner-driven parsing tests and should explicitly cover missing-CLI capability handling
- `kubernetes_dashboard_service_test.dart`
  - still valuable, but broader, more data-heavy, and should explicitly cover graceful degradation when the configured backend is unavailable
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

### Task 13.7: add `docker_client_service_test.dart`
Status: completed

What landed:
- [docker_client_service_test.dart](/home/home/personal/cwatch/test/model/features/docker/services/docker_client_service_test.dart)

Coverage added:
- Docker context JSON-line parsing with malformed-line tolerance
- Docker container parsing, including compose labels and `StartedAt`
- argument selection between `--context` and `--host`
- missing Docker CLI is surfaced as capability unavailability rather than treated like app-fatal failure

Why this matters:
- it locks down the current Docker CLI contract without requiring UI changes
- it matches the intended product direction:
  - system CLI integration is a convenience capability
  - missing CLI should degrade feature affordances, not imply the app itself is broken
- it gives later Docker refactors a regression floor around parsing and graceful-unavailable behavior

Verification:
- `flutter test test/model/features/docker/services/docker_client_service_test.dart`
- `flutter analyze`

### Task 13.8: add `kubernetes_dashboard_service_test.dart`
Status: completed

What landed:
- [kubernetes_dashboard_service_test.dart](/home/home/personal/cwatch/test/model/services_infra/kubernetes/kubernetes_dashboard_service_test.dart)

Coverage added:
- CLI backend data shaping for nodes, namespaces, workloads, pods, services, and events
- CLI backend graceful degradation to warnings and empty sections when `kubectl` calls fail
- API backend empty snapshot behavior when kubeconfig auth cannot be resolved
- API backend warning accumulation when some API calls fail but others succeed

Why this matters:
- it locks down Kubernetes dashboard shaping without needing widget tests
- it matches the intended capability model:
  - CLI/API integrations are optional runtime capabilities
  - missing or failing backends should degrade into warnings and empty states that UI layers can surface cleanly
- it gives later Kubernetes cleanup work a regression floor around both shaping and graceful-unavailable behavior

Verification:
- `flutter test test/model/services_infra/kubernetes/kubernetes_dashboard_service_test.dart`
- `flutter analyze`

### Task 13.9: add `path_loading_service_test.dart`
Status: completed

What landed:
- [path_loading_service_test.dart](/home/home/personal/cwatch/test/model/services/path_loading_service_test.dart)

Coverage added:
- skip behavior when the requested path is already current
- path normalization and filtering of `.` / `..`
- parent-row injection rules for root vs non-root paths
- search option forwarding and error results
- refresh behavior for empty and non-empty current paths
- cached-session hydration for file entries only

Why this matters:
- it locks down the service seam underneath the explorer workflow tests
- it validates path-shaping behavior independently from widget or controller code
- it gives later file-explorer cleanup work a regression floor around path loading and cached edit hydration

Verification:
- `flutter test test/model/services/path_loading_service_test.dart`
- `flutter analyze`

### Task 13.10: add `terminal_session_controller_test.dart`
Status: completed

What landed:
- [terminal_session_controller_test.dart](/home/home/personal/cwatch/test/controller/controllers/terminal_session_controller_test.dart)

Coverage added:
- session start wiring through `RemoteShellService.createTerminalSession`
- UTF-8 output forwarding
- exit-code callback forwarding
- write/resize passthrough to the active session
- reset/dispose teardown behavior
- replacing a session cancels the previous output subscription

Why this matters:
- it locks down the shared terminal lifecycle seam without widget complexity
- it covers behavior used by both SSH-backed terminal tabs and other terminal-driven flows
- it gives later session/lifecycle cleanup a regression floor before touching UI

Verification:
- `flutter test test/controller/controllers/terminal_session_controller_test.dart`
- `flutter analyze`

### Task 13.11: add `file_editing_service_test.dart`
Status: completed

What landed:
- [file_editing_service_test.dart](/home/home/personal/cwatch/test/model/services/file_editing_service_test.dart)

Coverage added:
- inline editor open behavior when an editor-tab hook is available
- local-open fallback messaging when inline editing is unavailable
- local cache creation and cached-session reuse
- sync behavior when:
  - remote matches snapshot
  - local copy is unchanged
  - local and remote diverged and require merge resolution
- refresh behavior when:
  - working copy is unchanged
  - merge is cancelled after remote changes
- cached-copy clearing

Why this matters:
- it locks down the file-editing seam underneath explorer/editor flows without requiring widget tests
- it gives the rewrite a regression floor around cache ownership, sync semantics, and merge handling
- it covers a high-risk user workflow where silent fallback behavior would otherwise be easy to break

Verification:
- `flutter test test/model/services/file_editing_service_test.dart`
- `flutter analyze`

### Task 13.12: add `resource_parser_test.dart`
Status: completed

What landed:
- [resource_parser_test.dart](/home/home/personal/cwatch/test/model/services/resource_parser_test.dart)

Coverage added:
- full snapshot shaping for:
  - CPU usage
  - memory and swap
  - load averages
  - disk usage and disk IO
  - process shaping
  - network totals
- malformed and partial section tolerance
- empty SSH output failure behavior

Why this matters:
- it locks down the server resource parsing seam without UI or live SSH dependencies
- it covers one of the remaining parser-heavy surfaces where malformed remote output could silently skew the UI
- it gives later server/resource cleanup a regression floor around both shaping and failure tolerance

Verification:
- `flutter test test/model/services/resource_parser_test.dart`
- `flutter analyze`

### Task 13.13: add `explorer_trash_manager_test.dart`
Status: completed

What landed:
- [explorer_trash_manager_test.dart](/home/home/personal/cwatch/test/model/services_infra/filesystem/explorer_trash_manager_test.dart)

Coverage added:
- move-to-trash behavior:
  - remote download call wiring
  - metadata persistence
  - change notification
- load behavior:
  - context filtering
  - malformed metadata tolerance
- restore behavior:
  - upload call wiring
  - restore-event emission
  - stored-entry removal
- delete behavior:
  - storage cleanup
  - change notification

Why this matters:
- it locks down the local-trash seam underneath delete/restore flows without involving UI adapters
- it covers one of the more stateful filesystem bridges where silent metadata drift would be expensive to debug later
- it gives the rewrite a regression floor around trash persistence and restore signaling

Verification:
- `flutter test test/model/services_infra/filesystem/explorer_trash_manager_test.dart`
- `flutter analyze`

### Task 13.14: add `file_explorer_tab_test.dart`
Status: completed

What landed:
- [file_explorer_tab_test.dart](/home/home/personal/cwatch/test/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_test.dart)

Coverage added:
- loading-state rendering while explorer initialization is still in progress
- inline non-timeout error rendering when initialization fails

Why this matters:
- it establishes the first widget-level regression seam without trying to snapshot the whole explorer interaction surface
- it locks down the highest-value top-level render states for the explorer tab before deeper widget coverage
- it keeps the widget test focused on user-visible state instead of reproducing the entire explorer service graph

Verification:
- `flutter test test/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_test.dart`
- `flutter analyze`

### Task 13.15: re-scope after the first widget seam
Status: completed

What this re-scope checked:
- whether to keep expanding `FileExplorerTab` widget coverage immediately
- or switch to the next highest-value UI seam after proving the first widget harness

Conclusion:
- do not broaden `FileExplorerTab` into a full interaction harness yet
- the next UI-facing batch should stay narrow and target one of:
  - terminal/editor shell surfaces
  - key dialogs that coordinate destructive or persistence-heavy actions

Why:
- `FileExplorerTab` already proved the first widget seam and exposed how expensive full-surface widget tests would be
- explorer behavior already has strong service/controller coverage underneath it
- the next best value is a smaller user-critical UI seam, not a giant explorer interaction matrix

Current best next target:
- a focused dialog/widget seam such as a port-forward or destructive-confirmation flow

What should wait:
- broad explorer gesture/selection widget coverage
- end-to-end widget harnesses that recreate large feature runtime graphs

Done definition:
- the first widget checkpoint is explicit
- the next UI-facing test batch is chosen based on risk and harness cost, not backlog order alone

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

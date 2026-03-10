# Testing Roadmap

Status: active
Purpose: define the minimum testing strategy needed to support the structural cleanup safely.

## Current State
- The repository currently has no Dart tests under `test/`.
- A rewrite without characterization coverage will be high-risk.
- The first goal is not broad coverage. The first goal is to capture current behavior around the highest-risk workflows.

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
1. `workspace_persistence_test.dart`
   - persist/restore behavior
   - signature comparisons
   - error handling on invalid saved state

2. `terminal_session_controller_test.dart`
   - start/write/resize/reset/dispose
   - output subscription behavior
   - error propagation

3. `explorer_ops_test.dart`
   - path loading and normalization
   - navigation history
   - search behavior
   - selection state changes

4. `path_loading_service_test.dart`
   - cached load vs forced load
   - list/search behavior
   - malformed/partial results

5. `file_editing_service_test.dart`
   - open/save/sync flows
   - cache behavior
   - merge conflict handling

### Priority 2
6. `docker_client_service_test.dart`
   - context parsing
   - container parsing
   - error handling and timeout behavior

7. `kubernetes_dashboard_service_test.dart`
   - CLI/API data shaping
   - warning collection
   - empty/error snapshot behavior

8. `resource_parser_test.dart`
   - CPU, memory, disk, processes, network parsing
   - malformed input handling

9. `explorer_trash_manager_test.dart`
   - move/restore/empty behavior
   - restore event handling

### Priority 3
10. `file_explorer_tab_test.dart`
    - loading/error/render states
    - search activation and key interaction

11. `settings_split_characterization_test.dart`
    - add once settings responsibilities begin to move out of `AppSettings`

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

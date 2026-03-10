# Rewrite Foundations

Status: active
Owner: current maintainers
Purpose: establish the first-pass scope for the structural rewrite and give future deep-dives a stable frame of reference.

## Why This Exists

CWatch is carrying accumulated design debt across feature, UI, and infrastructure layers. The immediate goal is not a blind rewrite. The goal is to make the existing problems explicit, sequence the work, and create a stable set of focus areas for deeper analysis and TODO documents.

## Current High-Level Findings

### 1. Layer boundaries are not enforced
- `lib/view/`, `lib/controller/`, and `lib/model/` are heavily cross-coupled.
- `controller` imports `view` in many places.
- `model` also imports `view` utilities in several paths.
- Result: the folder structure suggests separation, but dependencies do not.

### 2. Feature shells are doing composition, orchestration, and rendering at once
- Large views such as the servers, docker, kubernetes, and explorer screens build services, own async flows, manage persistence, register global actions, and render UI.
- Result: lifecycle bugs and behavior regressions are easy to introduce.

### 3. UI code owns too much behavior
- Many large `StatefulWidget` files contain domain logic, async control flow, persistence hooks, keyboard handling, and interaction rules.
- Result: logic becomes difficult to test or move without UI breakage.

### 4. Service composition is scattered
- Object creation is spread across bindings, widgets, and feature-specific setup code.
- Ownership and disposal are inconsistent.
- Result: replacement and refactoring of dependencies is expensive.

### 5. `AppSettings` is acting as a global dependency hub
- Configuration, feature flags, persisted workspace state, and view preferences all live in one model.
- Many modules listen directly to settings changes.
- Result: unrelated behavior is coupled through one state object.

### 6. Infrastructure behavior is mixed with feature policy
- SSH, Docker CLI, Kubernetes CLI/API, parsing, retries, and user-facing error handling are often blended into the same service paths.
- Result: fallbacks and error policy are hard to reason about.

### 7. Shared code ownership is unclear
- There are duplicated concepts, re-export shims, and feature-specific helpers living in shared paths.
- Result: it is hard to tell which abstraction is canonical.

### 8. Test coverage is not sufficient for a safe rewrite
- The repository currently has no Dart tests under `test/`.
- Result: a large cleanup effort needs characterization tests before substantial behavior changes.

## Rewrite Goals

### Goal 1: establish real dependency rules
Target outcome:
- direction of dependencies is explicit
- feature code does not reach across layers casually
- shared code has clear ownership

### Goal 2: separate composition from features
Target outcome:
- service creation is centralized
- lifecycle ownership is explicit
- features receive dependencies instead of constructing them ad hoc

### Goal 3: separate UI state, workflow state, and persisted settings
Target outcome:
- views render shaped state
- workflow coordinators own behavior
- persisted settings stop acting like a global event bus

### Goal 4: create safer seams around infrastructure
Target outcome:
- command execution, parsing, transport, and user-facing errors are isolated
- docker, kubernetes, ssh, and filesystem integrations have clearer interfaces

### Goal 5: make the rewrite testable
Target outcome:
- characterization coverage exists around the current critical flows
- new structure is introduced behind test seams, not by wholesale replacement

## Focus Areas For Deeper Analysis

### Focus Area A: architecture and dependency direction
Questions to answer:
- What is the target dependency model?
- Which imports are forbidden after cleanup?
- Which current shared modules should be moved or split?

Deliverables:
- dependency rules
- module/layer map
- migration constraints

### Focus Area B: app composition and lifecycle ownership
Questions to answer:
- Where should the composition root live?
- Which services are app-scoped, feature-scoped, or tab-scoped?
- Which disposals are currently implicit or unsafe?

Deliverables:
- composition root plan
- ownership matrix
- disposal/lifecycle audit

### Focus Area C: state model redesign
Questions to answer:
- Which state belongs in persisted settings?
- Which state belongs in feature controllers or view-models?
- Which state should be transient and local to the widget tree?

Deliverables:
- state taxonomy
- settings split proposal
- workspace persistence boundaries

### Focus Area D: vertical slice decomposition
Initial targets:
- servers
- docker
- file explorer
- kubernetes

Questions to answer:
- What is the minimum slice that proves the new architecture works?
- Which feature has the highest leverage with acceptable migration risk?

Deliverables:
- slice candidate ranking
- first-slice implementation plan
- anti-regression checklist

### Focus Area E: infrastructure boundary cleanup
Questions to answer:
- Where are transport, parsing, and policy mixed today?
- Which command-running services should become gateways?
- How should fallback behavior be represented explicitly?

Deliverables:
- infra boundary map
- gateway/repository proposal
- fallback/error-handling policy doc

### Focus Area F: testing foundations
Questions to answer:
- Which current flows must be characterized before refactor?
- Which units can be tested without UI?
- What minimal test harnesses are needed to make iterative cleanup viable?

Deliverables:
- characterization test backlog
- test seam map
- initial regression set

## Recommended Work Sequence

1. Document target dependency rules.
2. Define the composition root and service ownership model.
3. Split `AppSettings` responsibilities on paper before moving code.
4. Choose one vertical slice and design its target structure.
5. Add characterization tests around that slice.
6. Migrate that slice incrementally.
7. Repeat with the next highest-value slice.

## Planned Documentation Pass

### Phase 1: scope and alignment
- keep `README.md` aligned with the actual current codebase
- keep `AGENTS.md` aligned with the actual current codebase
- track rewrite scope in this document

### Phase 2: deeper analysis docs
Create separate follow-up docs for:
- dependency direction TODO (`docs/dependency_direction_todo.md`)
- shell/module ownership TODO (`docs/shell_module_ownership_todo.md`)
- docker/workspace ownership TODO (`docs/docker_workspace_ownership_todo.md`)
- workspace-core ownership TODO (`docs/workspace_core_ownership_todo.md`)
- explorer UI adapter ownership TODO (`docs/explorer_ui_adapter_ownership_todo.md`)
- server/WSL binding ownership TODO (`docs/server_wsl_binding_ownership_todo.md`)
- UI adapter dialog ownership TODO (`docs/ui_adapter_dialog_ownership_todo.md`)
- dependency rules
- settings/state split
- first vertical slice plan
- infrastructure boundary cleanup
- test strategy and characterization backlog

### Phase 3: implementation tracking
- add milestone checklists tied to actual refactor work
- link code changes back to the planning docs
- retire stale documents as they become obsolete

## Immediate TODO Seeds

### Top priority
- document current dependency violations by category
- document current service ownership and lifecycle rules
- identify a first vertical slice candidate
- create characterization tests for that slice before structural changes

### Follow-up
- split `AppSettings` into bounded concerns
- reduce feature entrypoint size and responsibilities
- move UI-only helpers fully into UI and non-UI helpers fully out of UI
- remove re-export shims that hide real ownership

## Constraints
- avoid broad rewrite-by-replacement
- keep behavior stable while introducing seams
- prefer incremental migration with explicit checkpoints
- update documentation whenever the target architecture meaningfully changes

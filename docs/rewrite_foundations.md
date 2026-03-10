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

## Target Boundary

The target architecture is not "controller/view/model, but cleaner."

The target architecture is:
- a reusable shell/framework layer
- removable feature modules
- explicit contracts between them

### Reusable shell/framework layer
This layer should survive removal of SSH, Docker, Kubernetes, and WSL feature modules.

It should own:
- tabbed workspace infrastructure
- reusable tab host and workspace primitives
- shared Flutter utility/widgets that are not feature-specific
- generic lists, menus, dialogs, configuration scaffolding, and input helpers
- dependency wiring for reusable app infrastructure
- generic persistence and state primitives that are not tied to one feature view

It should not own:
- feature-specific workflows
- feature-specific view composition
- feature-specific tab assembly
- feature-specific dialog content

### Feature modules
These are removable slices such as servers/SSH, Docker, Kubernetes, and WSL.

They should own:
- feature-specific views
- feature-specific tab assembly
- feature-specific workflow coordination
- feature-specific state and policies
- feature-specific dialog content and adapters unless the UI is truly reusable outside the feature

They may depend on reusable shell/framework primitives.

The shell/framework layer must not depend on feature implementation details except through explicit module registration or contracts.

### Practical dependency direction
- reusable shell/framework code may depend on shared non-feature Flutter/UI infrastructure
- feature modules may depend on shell/framework primitives and shared infrastructure
- feature modules must not be required for the shell/framework layer to exist
- anything under a feature tree that is needed by multiple features is a candidate to move into shared shell/framework ownership
- if removing a feature module breaks the shell rather than just unregistering feature functionality, the boundary is still wrong

## Required Workspace Contract

This is a strict architecture rule.

For any feature that participates in the tabbed shell:
- the shell/framework layer enforces a default initial tab state
- that default initial tab state is a placeholder tab
- the placeholder tab is the module's default workspace state until user input replaces it or expands it into working tabs

What the shell/framework is allowed to enforce:
- every tabbed module must provide an initial placeholder tab
- workspace restore and empty-state behavior start from that placeholder tab contract
- the placeholder tab is a valid tab kind in the shared workspace system

What the shell/framework must not enforce:
- a generic picker-page UI
- a list-based landing page
- a shared layout for module entry screens
- a shared interaction model beyond "initial placeholder tab exists"

What each feature module owns:
- the UI of its initial placeholder tab
- the behavior of that placeholder tab
- how placeholder input turns into working tabs
- whether the placeholder is a picker, launcher, dashboard, recent-work page, wizard, IDE home, or another feature-specific landing surface

The rule is:
- shared shell/framework code enforces the existence of the initial placeholder-tab pattern
- feature modules own everything about how that placeholder actually behaves and looks

This rule exists to solve shell/feature separation without forcing unrelated features into the same landing-page abstraction.

## Focus Areas For Deeper Analysis

### Focus Area A: architecture and dependency direction
Questions to answer:
- What is the target dependency model?
- What belongs to the reusable shell/framework layer versus removable feature modules?
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
- tab assembly ownership TODO (`docs/tab_assembly_ownership_todo.md`)
- theme registry ownership TODO (`docs/theme_registry_ownership_todo.md`)
- feature UI adapter ownership TODO (`docs/feature_ui_adapter_ownership_todo.md`)
- composition root ownership TODO (`docs/composition_root_ownership_todo.md`)
- settings state taxonomy TODO (`docs/settings_state_taxonomy_todo.md`)
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

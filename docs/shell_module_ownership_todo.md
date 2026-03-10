# Shell Module Ownership TODO

Status: active
Purpose: track the next dependency-direction cleanup around shell/module ownership without overcommitting the later refactor path.

## How To Use This Document

This document exists to define the next shell/module cleanup batch clearly enough to execute, then re-scope based on what we learn.

Use it to:
- track the current shell/module ownership problem
- define the next small implementation batch
- record the done definition for that batch
- re-scope the next batch after the current one lands

Do not treat later items here as fixed design decisions.

## Current Problem

The app shell and feature module ownership is split across multiple places:
- `lib/view/core/navigation/`
- `lib/controller/features/*/view.dart`
- `lib/controller/features/*_module.dart`
- `lib/controller/di/bindings/home_shell_services_binding.dart`

Current symptoms:
- controller-side module files import or export concrete view screens
- shell/module creation mixes feature descriptors, screen construction, and service wiring
- some bindings depend on view-owned types even when they are not presentation concerns
- it is hard to tell which layer owns module registration versus screen rendering versus service creation

This is a dependency-direction problem because it keeps `controller -> view` ownership blurred at the app shell level.

## Current Signal From The Codebase

Representative files:
- `lib/view/core/navigation/home_shell_controller.dart`
- `lib/view/core/navigation/home_shell_modules.dart`
- `lib/view/core/navigation/shell_module.dart`
- `lib/controller/features/servers/view.dart`
- `lib/controller/features/docker/view.dart`
- `lib/controller/features/kubernetes/view.dart`
- `lib/controller/features/settings/view.dart`
- `lib/controller/features/wsl/view.dart`
- `lib/controller/di/bindings/home_shell_services_binding.dart`

Patterns seen now:
- module definitions are created in `view/core/navigation/home_shell_modules.dart`, but the concrete module classes live under `controller/features/*`
- those controller feature files import `view/core/navigation/shell_module.dart` and concrete feature screens
- some controller feature files export view screens directly
- `HomeShellServicesBinding` still imports view-owned service holder types such as `home_shell_services.dart` and `gesture_detector_factory.dart`

## What We Are Trying To Improve

We are not trying to solve all `controller -> view` imports in one pass.

We are trying to make shell/module ownership less ambiguous by answering:
- where module descriptors should live
- where concrete screen construction should live
- where shell service creation should live
- which current controller feature files are just view wiring in the wrong place

## Working Rules For This Hotspot
- prefer one ownership fix at a time
- avoid renaming or moving all modules at once
- do not rebuild the shell architecture from scratch
- choose the smallest batch that makes ownership clearer
- re-scope after each batch

## First Batch Candidate

### Task 2.1: normalize feature module ownership entrypoints
Status: completed

Why this is first:
- the strongest shell/module ambiguity is the `controller/features/*/view.dart` pattern
- these files are currently the bridge between shell-module definitions and concrete screens
- cleaning this seam should teach us whether module descriptors belong with the shell or with presentation

Current files in scope:
- `lib/controller/features/servers/view.dart`
- `lib/controller/features/docker/view.dart`
- `lib/controller/features/kubernetes/view.dart`
- `lib/controller/features/settings/view.dart`
- `lib/controller/features/wsl/view.dart`
- `lib/controller/features/debug_logs/view.dart`
- `lib/controller/features/docker/docker_module.dart`
- `lib/controller/features/kubernetes/kubernetes_module.dart`
- `lib/controller/features/settings/settings_module.dart`

Actions:
- inspect the controller feature entrypoint files and group them by role:
  - module descriptor
  - view constructor wrapper
  - plain re-export shim
- decide one narrow ownership correction for the first pass
- implement only that correction
- update shell/module imports to match

Done definition:
- one ownership rule is clearer than before for feature module entrypoints
- at least one misleading controller-side view export/import pattern is removed
- the resulting structure is simpler to reason about than the current split

Verification:
- `rg -n "package:cwatch/view/" lib/controller/features`
- `flutter analyze`
- manual smoke check that shell navigation still loads modules

### Task 2.2: re-scope after feature entrypoint cleanup
Status: completed

### Task 2.3: inspect home shell service binding ownership
Status: completed

### Task 2.4: decide gesture factory ownership
Status: completed

Why this is next:
- `HomeShellServices` is no longer view-owned
- the remaining view import in `HomeShellServicesBinding` is `gesture_detector_factory.dart`
- this is now a single isolated ownership question instead of a mixed binding/service-holder problem

Actions:
- decide whether `GestureDetectorFactory` is correctly view-owned or should move closer to shell/controller composition
- make one narrow correction if the current ownership is misleading
- otherwise document the exception explicitly in this TODO

Done definition:
- the remaining `controller/di -> view` dependency in `HomeShellServicesBinding` is either removed or explicitly justified
- the shell binding ownership story is clearer than it is today

Verification:
- `rg -n "package:cwatch/view/" lib/controller/di/bindings/home_shell_services_binding.dart`
- `flutter analyze`
- manual shell bootstrap smoke check

Why this is next:
- module descriptors now live with the shell
- the next strongest ownership ambiguity is `HomeShellServicesBinding` creating a view-owned service holder and importing view-owned helper types

Actions:
- inspect `home_shell_services.dart`, `gesture_detector_factory.dart`, and `HomeShellServicesBinding`
- decide one narrow ownership correction for that seam
- implement only the smallest change that makes service ownership clearer

Done definition:
- one shell service ownership rule is clearer than before
- at least one non-presentation dependency on a view-owned type is removed or explicitly justified

Verification:
- `rg -n "package:cwatch/view/" lib/controller/di/bindings/home_shell_services_binding.dart`
- `flutter analyze`
- manual shell bootstrap smoke check

Purpose:
- decide whether the next shell/module batch should target:
  - remaining feature entrypoints
  - `home_shell_modules.dart`
  - `HomeShellServicesBinding`
- record what we learned about ownership from Task 2.1

Done definition:
- the next shell/module task is written from the post-2.1 state of the code
- any newly discovered ownership rule or exception is recorded here

Verification:
- follow-up task added to this document before the next shell/module structural change starts

Result of re-scope:
- shell module descriptors now live under `view/core/navigation/feature_modules.dart`
- controller-side feature module entrypoint and barrel files were removed
- `home_shell_modules.dart` now reads as a shell-owned module list instead of a shell file depending on controller-owned module wrappers
- the next shell/module batch should focus on `HomeShellServicesBinding` ownership

Updated result after Task 2.3:
- `HomeShellServices` moved out of `view/` into `controller/di/`
- `HomeShellServicesBinding` no longer depends on a view-owned service holder
- the remaining binding-side view dependency is isolated to `gesture_detector_factory.dart`

## Later Work In This Hotspot

Do not expand these until Task 2.1 has landed.

### Shell module registry and builder ownership
Track here when ready:
- whether `home_shell_modules.dart` should keep building module lists
- whether module descriptor types are owned by `view/core/navigation` or elsewhere

### Home shell service binding ownership
Track here when ready:
- whether `HomeShellServicesBinding` should keep constructing a view-owned service holder
- whether `gesture_detector_factory.dart` and `home_shell_services.dart` should remain under `view/`

### Controller-to-view exceptions that are acceptable
Track here when ready:
- which controller-to-view imports are temporary shell wiring
- which ones are genuinely wrong ownership and should be removed

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 2.1 | Feature module entrypoints | completed | one shell/module ownership rule is clearer and at least one misleading pattern is removed |
| 2.2 | Shell/module re-scope | completed | next shell/module batch is written from what we learned in 2.1 |
| 2.3 | Home shell service binding ownership | completed | one shell service ownership rule is clearer and at least one non-presentation view dependency is addressed |
| 2.4 | Gesture factory ownership | completed | remaining binding-side view dependency is removed or justified |
| 2.x | Module registry/binding follow-up | queued | re-scoped after 2.4 |

## Shell/module checkpoint

Current state:
- shell module descriptors live with the shell
- controller-side feature module entrypoint wrappers are gone
- `HomeShellServicesBinding` no longer imports from `view/`
- the main remaining `controller -> view` imports are now outside the narrow shell/module seam

Decision:
- this hotspot is at a good stopping point
- the next dependency-direction work should shift to feature/workspace ownership, not continue forcing shell-only cleanup

Likely next targets:
- docker overview bindings and docker view-side helper ownership
- workspace core types that still depend on view-owned tab classes
- explorer adapters/controllers that still depend on concrete view-local helper types

## Completion Metric

This document is serving its purpose if:
- it defines the next shell/module batch clearly enough to execute
- it reduces ownership ambiguity without requiring a full shell rewrite
- it gets re-scoped after each batch instead of predicting the whole sequence up front

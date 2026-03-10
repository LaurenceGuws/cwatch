# Composition Root Ownership TODO

Status: active
Purpose: scope the next rewrite layer after dependency-direction cleanup: service creation and runtime wiring ownership.

## Boundary This Hotspot Must Respect

The reusable shell/framework layer should provide stable composition rules, not force feature views to assemble large service graphs ad hoc.

Feature modules may still assemble feature-local pieces, but the ownership should be explicit:
- app-scoped services
- module-scoped services
- tab-scoped services
- widget-local UI helpers

The problem is not merely "too many bindings."

The problem is that feature views currently act as:
- composition root
- lifecycle owner
- async bootstrap coordinator
- screen renderer

all at once.

## Current Problem

The dependency-direction cleanup removed many wrong-direction imports, but large feature views still construct broad runtime graphs directly.

Strong examples:
- [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)

Current symptoms:
- multiple bindings created inside one view state object
- feature view `initState` doing object construction, settings wiring, async restore, registry registration, and UI lifecycle management
- service ownership/disposal spread between bindings, controllers, and the widget itself

## Why This Matters

At this stage, import cleanup alone will not buy much more.

The next source of coupling and rewrite risk is construction ownership:
- who creates what
- who disposes what
- what should be app/module/tab scoped
- what should be injected versus assembled inline

Until that is clearer, the shell/framework layer will still feel tightly coupled to feature views even if the imports look cleaner.

## Working Rules For This Hotspot
- do not attempt a global DI rewrite in one pass
- start with one feature shell that shows the pattern clearly
- prefer extracting ownership rules and one narrow construction seam over inventing a container framework
- treat lifecycle/disposal as part of ownership, not an afterthought
- re-scope after the first batch lands

## First Batch Candidate

### Task 11.1: inspect docker view construction ownership
Status: queued

Why this is first:
- `DockerView` is a concentrated example of view-owned service/controller construction
- it appears smaller and less coupled than the server workspace shell
- it should let us define one concrete composition rule without touching the heaviest feature first

Current files in scope:
- `lib/view/features/docker/docker_view.dart`
- `lib/controller/di/bindings/docker_view_binding.dart`
- `lib/controller/di/bindings/docker_overview_binding.dart`
- `lib/controller/di/bindings/docker_client_service_binding.dart`
- any directly related docker controllers/services needed to classify ownership

Actions:
- inspect what `DockerView` constructs and owns today
- classify constructed objects by scope:
  - app/module/tab/widget-local
- identify one misleading construction seam
- make one narrow correction or create one narrow composition object that clarifies ownership
- record the rule learned from that batch

Done definition:
- one concrete part of docker runtime construction no longer lives ambiguously in the view state object
- ownership/lifecycle of that part is clearer than it is today
- the next composition-root step can be scoped from evidence instead of a guessed DI rewrite

Verification:
- `flutter analyze`
- manual smoke check of docker view load and overview interactions

### Task 11.2: re-scope after docker construction review
Status: queued

Purpose:
- decide whether the next batch should stay in docker
- or apply the same ownership rule to server/kubernetes shells

Done definition:
- the next step is written from what Task 11.1 proves
- any ownership rule or intentional exception is recorded here

Verification:
- follow-up task added before the next structural change starts

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 11.1 | Docker construction ownership | queued | one concrete docker construction seam has explicit ownership |
| 11.2 | Composition hotspot re-scope | queued | next step is written from what 11.1 proves |

## Completion Metric

This document is serving its purpose if:
- it shifts the cleanup from import shape to runtime ownership
- it avoids pretending we already know the final DI/container model
- it gives one narrow, executable construction-ownership step with a clear done definition

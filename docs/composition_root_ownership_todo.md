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

This hotspot must also respect the enforced workspace contract:
- the shell/framework enforces that each module has an initial placeholder tab
- the feature module owns the UI and behavior of that placeholder tab
- composition cleanup must not drift into a generic picker-page abstraction

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
Status: completed

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
Status: completed

Purpose:
- decide whether the next batch should stay in docker
- or apply the same ownership rule to server/kubernetes shells

Done definition:
- the next step is written from what Task 11.1 proves
- any ownership rule or intentional exception is recorded here

Verification:
- follow-up task added before the next structural change starts

Result of Task 11.1:
- Docker module-scoped runtime construction moved behind `DockerViewBinding.createRuntime(...)`
- `DockerView` now owns one explicit `DockerViewRuntime` instead of assembling the module-scoped graph field-by-field in `initState`
- `DockerViewRuntime` now owns disposal for:
  - `DockerWorkspaceController`
  - `DockerViewController`
  - `PortForwardService`
- this clarified one useful rule:
  - feature views should wire UI listeners/registries and invoke runtime behavior
  - module-scoped service/controller graphs should be assembled as one explicit runtime object

### Task 11.3: decide whether to apply the same runtime-graph pattern to server or kubernetes
Status: completed

Why this is next:
- Docker now provides a concrete composition pattern
- the next question is whether server or kubernetes is the better second example for runtime-graph extraction
- this should be chosen from current code shape, not from a pre-written migration script

Actions:
- inspect server and kubernetes feature shells against the Docker runtime pattern
- choose the smaller/higher-value next runtime ownership seam
- define the next narrow batch from evidence

Done definition:
- the next composition-root batch is written from what the Docker pass proved
- any intentional exception to the runtime-object pattern is recorded here

Verification:
- follow-up task added before the next structural change starts

Result of Task 11.3:
- Kubernetes is the better second runtime-graph target
- `KubernetesContextList` still assembles a module-scoped graph directly, but the graph is smaller and less entangled than the server workspace shell
- `ServerWorkspaceView` remains the heavier follow-up because it still mixes:
  - host loading and availability probing
  - shell factory wiring
  - port-forward controller wiring
  - settings controller wiring
  - feature-specific async orchestration

### Task 11.4: extract a Kubernetes module runtime
Status: completed

Why this is next:
- it applies the Docker runtime pattern to a second, smaller feature shell
- it should confirm whether the pattern generalizes before touching the heavier server shell

Current files in scope:
- `lib/view/features/kubernetes/kubernetes_context_list.dart`
- `lib/controller/di/bindings/kubernetes_context_binding.dart`
- `lib/controller/di/bindings/settings_binding.dart`
- `lib/view/features/kubernetes/kubernetes_workspace_controller.dart`
- `lib/view/features/kubernetes/kubernetes_tab_builder.dart`

Actions:
- identify the module-scoped runtime graph currently assembled in `KubernetesContextList.initState`
- extract that graph into one explicit runtime object
- make the feature view own the runtime object plus UI listeners/registries
- keep widget-local selection/list state in the view

Done definition:
- `KubernetesContextList` no longer constructs its module-scoped graph field-by-field in `initState`
- runtime ownership/disposal for that graph is clearer than it is today
- the Docker runtime pattern is validated on a second feature shell

Verification:
- `flutter analyze`
- manual smoke check of Kubernetes context loading and workspace restore

Result of Task 11.4:
- `KubernetesContextList` now owns one `KubernetesRuntime` instead of assembling its module-scoped graph field-by-field
- `KubernetesContextBinding.createRuntime(...)` now assembles:
  - `KubernetesContextController`
  - `SettingsController`
  - `KubernetesTabBuilder`
  - `KubernetesWorkspaceController`
  - `KubernetesUiAdapter`
- `KubernetesRuntime` now owns disposal of the module-scoped controllers
- this validates the Docker runtime pattern on a second feature shell

### Composition-root hotspot checkpoint
Status: active

Current pattern established:
- feature view owns:
  - widget-local UI state
  - initial placeholder tab UI and behavior
  - listeners/registries
  - view-specific async triggers
- runtime object owns:
  - module-scoped controller/service graph
  - disposal of that graph

Important limit:
- runtime extraction must support the module-defined initial placeholder-tab contract
- it must not centralize the landing-page implementation in shell/framework code

### Task 11.5: re-scope server shell against the runtime-object pattern
Status: completed

Why this is next:
- Docker and Kubernetes now show the same composition pattern
- server is the heavier shell and should be approached with that evidence
- the next step should identify the smallest server runtime extraction, not attempt a full shell rewrite

Done definition:
- the next server composition-root batch is written from what Docker and Kubernetes proved
- any reason the server shell needs a staged runtime extraction is recorded here

Verification:
- follow-up task added before the next structural change starts

Result of Task 11.5:
- server should use a staged runtime extraction, not a full-shell runtime move in one pass
- the module-scoped runtime graph is mixed today with feature-owned landing behavior and host-list orchestration
- the first extraction should take only the clearly module-scoped service graph:
  - `ServerWorkspaceUiAdapter`
  - `SshShellFactory`
  - `HostDistroManager`
  - `PortForwardService`
  - `ServerPortForwardController`
  - `SettingsController`
  - `ServerTabBuilder`
  - `ServerWorkspaceController`
- the server feature view should keep ownership of:
  - host loading
  - host availability probing
  - `_hostsFutureNotifier`
  - placeholder tab creation
  - placeholder/list landing behavior
  - action flows that replace placeholder tabs with working tabs

Why this staging is required:
- the placeholder tab contract is strict
- server landing behavior is feature-owned and should not be centralized into a generic runtime/container abstraction
- host loading is currently intertwined with the server landing surface, not just the service graph

### Task 11.6: extract the server module runtime without moving placeholder behavior
Status: queued

Why this is next:
- it applies the validated runtime-object pattern to the heaviest remaining shell
- it keeps the high-risk part out of scope:
  - placeholder tab UI/behavior
  - host loading/orchestration

Current files in scope:
- `lib/view/features/servers/server_workspace_view.dart`
- `lib/controller/di/bindings/server_workspace_binding.dart`
- `lib/controller/di/bindings/ssh_shell_factory_binding.dart`
- `lib/controller/di/bindings/settings_binding.dart`
- `lib/view/features/servers/server_tab_builder.dart`
- `lib/view/features/servers/server_workspace_controller.dart`

Actions:
- extract a `ServerWorkspaceRuntime` for the clearly module-scoped graph
- leave host-loading futures, notifier state, placeholder-tab creation, and landing behavior in the feature view
- make disposal of the extracted graph explicit in the runtime object
- do not introduce a generic picker/placeholder abstraction

Done definition:
- `ServerWorkspaceView` no longer constructs the extracted module-scoped graph field-by-field in `initState`
- server placeholder-tab behavior remains feature-owned in the view
- runtime ownership/disposal of the extracted graph is clearer than it is today

Verification:
- `flutter analyze`
- manual smoke check of server landing tab, add-server flow, and one action transition from placeholder to working tab

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 11.1 | Docker construction ownership | completed | one concrete docker construction seam has explicit ownership |
| 11.2 | Composition hotspot re-scope | completed | next step is written from what 11.1 proves |
| 11.3 | Next runtime-graph target | completed | next composition-root batch is chosen from current evidence |
| 11.4 | Kubernetes runtime graph | completed | Kubernetes module-scoped runtime construction is explicit |
| 11.5 | Server runtime re-scope | completed | next server batch is chosen from the validated runtime-object pattern |
| 11.6 | Server staged runtime extraction | queued | extracted server runtime graph is explicit while placeholder behavior stays feature-owned |

## Completion Metric

This document is serving its purpose if:
- it shifts the cleanup from import shape to runtime ownership
- it avoids pretending we already know the final DI/container model
- it gives one narrow, executable construction-ownership step with a clear done definition

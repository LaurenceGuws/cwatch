# Infrastructure Boundary TODO

Status: active
Purpose: turn infrastructure boundary cleanup into an implementation backlog after the four vertical-slice checkpoints, so Docker, Kubernetes, and SSH policy cleanup can proceed one bounded seam at a time.

## Why This Exists

The feature-slice sequence proved that top-level feature shells can now hold cleaner boundaries.

What remains structurally unclear is not primarily shell/view ownership anymore.

It is infrastructure ownership around:
- transport
- parsing
- capability detection
- retry policy
- degradation policy
- user-facing failure mapping

Those concerns still cut across Docker, Kubernetes, and SSH code paths.

## What This Layer Is Not

This layer is not:
- a generic networking framework rewrite
- replacing all CLI integrations with API clients
- removing optional system CLI integrations
- collapsing Docker, Kubernetes, and SSH into one transport abstraction

This layer is:
- separating transport execution from feature policy
- making capability-aware degradation explicit and reusable
- identifying where parsing and retry logic belong
- reducing hidden fallback/plaster behavior

## Working Rules

- start from one narrow policy seam, not all infra at once
- do not erase the product rule that system CLIs are optional convenience integrations
- keep builtin paths first-class where the product already treats them that way
- prefer explicit service contracts over new global managers
- treat user-facing degradation wording as feature-owned unless the state itself is truly shared

## Current System-Wide Smells

### 1. Transport and policy are still mixed
Examples:
- Docker CLI execution and capability handling are mixed in [docker_client_service.dart](/home/home/personal/cwatch/lib/model/features/docker/services/docker_client_service.dart)
- Kubernetes CLI/API fallback and warning shaping are mixed in [kubernetes_dashboard_service.dart](/home/home/personal/cwatch/lib/model/services_infra/kubernetes/kubernetes_dashboard_service.dart)
- SSH runtime, auth, and provider-specific behavior still have cleanup tail after the auth checkpoint

### 2. Capability detection is explicit, but not yet normalized as a boundary
The rule is now documented and partially tested:
- missing CLI/provider support should degrade affordances, not behave as app-fatal failure

But ownership is still uneven:
- some services throw raw infra exceptions
- some controllers convert those into capability-aware states
- some views still decide unavailable-state behavior ad hoc

### 3. Parsing and user-facing failure mapping are not consistently split
Current services often do more than one job:
- execute command / transport
- parse output
- decide retry/fallback path
- shape user-facing error/warning behavior

That keeps policy hard to move and harder to test cleanly.

## Recommended First Target

The first infrastructure-boundary batch should target:
- Docker capability + transport/policy ownership

Why Docker first:
- it already has focused service tests
- capability-aware missing-CLI behavior is already explicit in product direction and recent fixes
- the seam is narrower than Kubernetes CLI/API dual-path policy
- it is lower-risk than reopening SSH transport/auth policy immediately

## Task 19.1: confirm the first infrastructure-boundary seam
Status: completed

Goal:
- choose the first bounded infra-policy seam after the vertical-slice sequence

Candidates considered:
- Docker capability + transport/policy ownership
- Kubernetes CLI/API policy split
- SSH provider/runtime policy cleanup

Result:
- Docker capability + transport/policy ownership is first

Why this wins:
- it has the clearest narrow seam
- it already has direct regression coverage in `docker_client_service_test.dart`
- it lets us prove the policy split without reopening the heavier SSH or dual-backend Kubernetes paths first

## Task 19.2: define the Docker infrastructure boundary target
Status: completed

Goal:
- describe what part of the current Docker path is transport, what part is parsing, and what part is capability/degradation policy

Questions to answer:
- what should remain in `DockerClientService`
- what should move to a narrower transport or capability seam
- what should remain feature-owned in Docker views/controllers

Done definition:
- the first Docker infra boundary is explicit
- one concrete implementation batch is chosen

Result:
- the first Docker infrastructure boundary is now explicit

### Current responsibility mix in `DockerClientService`

`DockerClientService` currently does three jobs at once:
1. transport execution
- building `docker` command arguments
- running the process
- applying timeout behavior

2. output parsing
- parsing Docker context JSON lines
- parsing container JSON lines and label maps
- parsing typed Docker model values like `StartedAt`

3. capability/degradation policy
- detecting missing Docker CLI through `ProcessException`
- converting missing CLI into a capability-style exception message
- converting timeout behavior into user-consumable failure text

That is the real boundary smell.

### What should stay stable in the first Docker infra batch

These areas should stay stable for the first pass:
- Docker feature views/controllers
- current capability-aware UI behavior in Docker picker/dashboard surfaces
- current Docker model types
- current feature-level remediation wording

Why they stay stable:
- the first infra batch should not spread into Docker feature presentation again
- the problem to solve first is the service boundary, not the Docker UI state model

### Proposed target boundary

For the first pass, split the current service responsibility into:
- transport seam
  - execute Docker CLI requests and return raw `ProcessResult`/raw output
- parsing seam
  - convert raw Docker CLI output into typed Docker models
- capability policy seam
  - classify missing CLI / timeout / command failure into explicit Docker capability/infrastructure failures

### What should remain in `DockerClientService` after the first pass

`DockerClientService` should remain the Docker-facing gateway used by higher layers, but it should stop owning all of the low-level work directly.

It should own:
- operation-level API shape (`listContexts`, `listContainers`, etc.)
- Docker-specific argument selection for those operations
- combining lower seams into one Docker gateway result for callers

It should not keep owning:
- inline JSON-line parsing implementation for every operation
- low-level capability classification logic mixed into each method

### What should remain feature-owned

Feature layers should still own:
- how unavailable Docker capability is shown to the user
- whether an unavailable state becomes a picker empty state, warning, or disabled action
- Docker-specific remediation wording and breadcrumbs

They should not need to know:
- how missing CLI is detected
- how process execution differs from parse failure
- how timeout failure is classified

### First implementation batch

The first Docker infra batch should extract:
- Docker CLI execution into a narrow runner/executor seam
- Docker CLI failure classification into a small typed capability/infrastructure error seam

Parsing can remain in `DockerClientService` for that first batch.

Why this is the right first cut:
- it removes the most repeated policy logic first
- it gives a clearer distinction between:
  - CLI unavailable
  - command failed
  - timed out
- it avoids splitting everything at once
- it preserves the current tests as a useful floor

## Task 19.3: implement the first Docker transport/capability split
Status: completed

Goal:
- extract a narrow Docker CLI execution/failure-classification seam while keeping the Docker-facing gateway API stable

First code targets:
- `DockerClientService`
- a new Docker CLI executor/failure type seam under `lib/model/features/docker/services/`
- `docker_client_service_test.dart` updates/expansion around typed failure behavior

What should stay stable in this batch:
- Docker feature views/controllers
- Docker model parsing shape
- capability-aware UI rendering behavior

Done definition:
- `DockerClientService` no longer owns raw process execution and missing-CLI/timeout classification inline in each method
- the new seam makes transport failure categories explicit
- existing Docker caller behavior stays stable from the feature layer perspective

Result:
- added [docker_cli_executor.dart](/home/home/personal/cwatch/lib/model/features/docker/services/docker_cli_executor.dart)
- added [docker_cli_failure.dart](/home/home/personal/cwatch/lib/model/features/docker/services/docker_cli_failure.dart)
- updated [docker_client_service.dart](/home/home/personal/cwatch/lib/model/features/docker/services/docker_client_service.dart) to delegate raw process execution to the executor seam
- kept the Docker-facing gateway API stable by mapping typed executor failures back into the same caller-facing exception messages
- expanded [docker_client_service_test.dart](/home/home/personal/cwatch/test/model/features/docker/services/docker_client_service_test.dart) with direct typed-failure coverage for:
  - CLI unavailable
  - timeout

## Task 19.4: re-scope the next Docker infrastructure batch
Status: completed

Goal:
- decide whether the next Docker infra step should split parsing from the gateway or checkpoint and move to another infrastructure seam

Questions to answer:
- is Docker parsing the next real boundary
- or is the next higher-value system-wide move Kubernetes CLI/API policy cleanup

Done definition:
- the next infrastructure batch is explicit
- the choice is based on the post-executor code shape, not a prewritten multi-step rewrite

Result:
- Docker parsing is not the highest-value next move
- the next infrastructure seam should be Kubernetes CLI/API policy cleanup

Why:
- Docker now has a clearer transport/failure seam and useful direct coverage
- parsing inside `DockerClientService` is still mixed, but it is lower-risk and mostly local to one gateway
- Kubernetes still mixes more concerns in one place:
  - backend selection
  - CLI vs API transport choice
  - warning accumulation
  - partial-failure handling
  - empty-snapshot degradation behavior
- that makes Kubernetes the stronger next system-wide policy seam

## Task 19.5: define the Kubernetes infrastructure boundary target
Status: completed

Goal:
- describe what part of the current Kubernetes dashboard path is transport, what part is shaping/parsing, and what part is backend/failure policy

Questions to answer:
- what should remain in `KubernetesDashboardService`
- what should move to a narrower backend-policy seam
- what should remain feature-owned in Kubernetes views/controllers

Done definition:
- the first Kubernetes infra boundary is explicit
- one concrete implementation batch is chosen

Result:
- the first Kubernetes infrastructure boundary is now explicit

### Current responsibility mix in `KubernetesDashboardService`

`KubernetesDashboardService` currently does four jobs at once:
1. backend policy
- choosing CLI vs API path from `KubernetesBackend`
- deciding when auth-resolution failure becomes an empty snapshot

2. transport orchestration
- issuing kubectl requests
- issuing API requests
- sequencing all collection calls for both backends

3. shaping/parsing
- parsing raw kubectl/API payloads into typed dashboard rows
- building the summary and final snapshot

4. degradation policy
- accumulating warnings
- converting partial failures into empty sections
- deciding when the result is an empty snapshot vs partial snapshot

That is the main boundary smell.

### What should stay stable in the first Kubernetes infra batch

These areas should stay stable for the first pass:
- Kubernetes feature views/controllers
- current dashboard widget rendering
- current typed snapshot/row models
- current user-facing warning wording

Why they stay stable:
- the first infra batch should not spread back into feature presentation
- the problem to solve first is service policy ownership, not dashboard UI structure

### Proposed target boundary

For the first pass, split the current service responsibility into:
- backend policy seam
  - choose CLI vs API collection path
  - classify auth-resolution failure / backend unavailability into explicit dashboard collection outcomes
- transport collection seams
  - one CLI collector
  - one API collector
- shaping seam
  - convert collected raw payloads into typed dashboard snapshot data

### What should remain in `KubernetesDashboardService` after the first pass

`KubernetesDashboardService` should remain the Kubernetes-facing gateway used by higher layers, but it should stop owning backend-policy and collection logic inline.

It should own:
- operation-level API shape (`load(...)`)
- combining lower seams into one dashboard snapshot result for callers
- preserving the current caller-facing snapshot contract

It should not keep owning:
- inline CLI vs API branching and collection orchestration
- inline warning/degradation policy for every backend path

### What should remain feature-owned

Feature layers should still own:
- how warnings and unavailable state are shown to the user
- Kubernetes-specific remediation wording and dashboard presentation
- whether warnings are shown as banners, empty states, or secondary details

They should not need to know:
- how backend selection is implemented
- how auth-resolution failure differs from partial data collection failure
- how CLI/API collection failures are accumulated internally

### First implementation batch

The first Kubernetes infra batch should extract:
- backend collection policy into a narrow collector seam
- one explicit collection result shape that separates:
  - collected data
  - warnings
  - empty/partial collection outcomes

Raw parsing can remain in `KubernetesDashboardService` for that first batch.

Why this is the right first cut:
- backend-selection and degradation policy are the densest mixed concern today
- it gives a clearer distinction between:
  - auth resolution failure
  - backend collection failure
  - partial data collection with warnings
- it avoids splitting transport and parsing at the same time
- it preserves the current tests as a useful floor

## Task 19.6: implement the first Kubernetes backend-policy split
Status: completed

Goal:
- extract a narrow Kubernetes backend collection/policy seam while keeping the dashboard-facing gateway API stable

First code targets:
- `KubernetesDashboardService`
- a new Kubernetes dashboard collection/policy seam under `lib/model/services_infra/kubernetes/`
- `kubernetes_dashboard_service_test.dart` updates/expansion around explicit collection outcomes

What should stay stable in this batch:
- Kubernetes feature views/controllers
- dashboard row parsing shape
- warning wording observed by the feature layer

Done definition:
- `KubernetesDashboardService` no longer owns inline CLI/API backend-policy and degradation logic in one block
- the new seam makes backend collection outcomes explicit
- existing Kubernetes caller behavior stays stable from the feature layer perspective

Result:
- added `KubernetesDashboardCollector` as the backend collection/policy seam
- added `KubernetesDashboardCollectionResult` as the explicit collection outcome shape
- `KubernetesDashboardService` now delegates backend selection, auth-null handling, warning accumulation, and partial/empty collection policy to the collector
- `KubernetesDashboardService` now focuses on parsing raw payload maps and shaping `KubernetesDashboardSnapshot`
- existing dashboard behavior stayed stable under service tests

Validation:
- `flutter test test/model/services_infra/kubernetes/kubernetes_dashboard_service_test.dart`
- `flutter analyze`

## Task 19.7: re-scope the next infrastructure batch
Status: completed

Goal:
- choose the highest-value next infrastructure boundary after the first Docker and Kubernetes splits

Candidates considered:
- deeper Docker parsing extraction
- deeper Kubernetes transport/parser split
- SSH provider/runtime policy cleanup

Result:
- the next infrastructure seam should be SSH provider/runtime policy cleanup

Why this wins:
- Docker now has a usable transport/failure seam
- Kubernetes now has a usable backend collection/policy seam
- both still have local parsing/transport cleanup tail, but that work is narrower and less system-wide
- SSH still carries broader infrastructure ambiguity around:
  - provider selection
  - builtin vs system path policy
  - runtime failure mapping
  - capability-aware degradation ownership
- that makes SSH the stronger next cross-cutting infrastructure seam

Next step:
- Task 19.8: define the SSH infrastructure boundary target

## Task 19.8: define the SSH infrastructure boundary target
Status: completed

Goal:
- describe what part of the current SSH path is provider selection, what part is runtime transport/session ownership, and what part is failure/capability policy

Questions to answer:
- what should remain in `SshShellFactory`
- what should move to a narrower provider/runtime seam
- what should remain feature-owned in server/docker/editor/explorer call sites

Done definition:
- the first SSH infra boundary is explicit
- one concrete implementation batch is chosen

Result:
- the first SSH infrastructure boundary is now explicit

### Current responsibility mix in `SshShellFactory`

`SshShellFactory` currently does three jobs at once:
1. provider selection policy
- choosing builtin vs process SSH from `sshPreferences.clientBackend`
- deciding whether timeout-specific builtin transport is needed

2. runtime transport/session ownership
- constructing builtin shell services through `BuiltInSshKeyService`
- constructing process shell services
- caching provider instances by derived signatures
- resetting cached instances on settings changes

3. infrastructure policy inputs
- threading auth coordinator, known-hosts handling, host-key bindings, observer wiring, and timeout policy into the runtime
- implicitly deciding which provider capabilities exist for the caller

That is the main SSH boundary smell.

### What should stay stable in the first SSH infra batch

These areas should stay stable for the first pass:
- feature call sites that ask for `RemoteShellService`
- SSH auth dialog ownership and built-in auth coordination behavior already checkpointed earlier
- current `RemoteShellService` caller-facing contract
- current feature-level unavailable/error wording

Why they stay stable:
- the first SSH infra batch should not reopen shell/view ownership or auth UI flows
- the problem to solve first is provider/runtime policy ownership, not session UI or terminal/editor behavior

### Proposed target boundary

For the first pass, split the current SSH responsibility into:
- provider policy seam
  - choose builtin vs process transport from settings/capability inputs
  - classify which provider/runtime variant is required
- runtime factory seam
  - build/cache concrete `RemoteShellService` instances for the chosen provider/runtime signature
- feature policy seam
  - keep feature layers responsible only for how unavailable/error states are surfaced

### What should remain in `SshShellFactory` after the first pass

`SshShellFactory` should remain the SSH-facing gateway used by higher layers, but it should stop owning provider-selection and runtime caching as one inline block.

It should own:
- operation-level API shape (`forHost(...)`, `handleSettingsChanged(...)`)
- combining lower seams into one shell gateway for callers
- preserving the current caller-facing `RemoteShellService` contract

It should not keep owning:
- inline provider-selection branching and signature classification
- inline runtime cache lifecycle for every provider variant

### What should remain feature-owned

Feature layers should still own:
- how SSH capability absence or runtime failures are shown to the user
- whether unavailable state becomes a disabled action, breadcrumb, or warning
- domain-specific remediation wording

They should not need to know:
- how builtin vs process provider is selected
- how runtime caching is implemented
- how timeout variants differ from default provider instances

### First implementation batch

The first SSH infra batch should extract:
- provider selection/signature classification into a narrow selector seam
- one explicit provider-runtime request shape carrying:
  - selected backend
  - timeout variant
  - signature inputs needed for cache selection

Runtime construction/caching can remain in `SshShellFactory` for that first batch.

Why this is the right first cut:
- it removes the densest policy branching first
- it gives a cleaner distinction between:
  - provider choice
  - runtime instance ownership
  - feature-level unavailable behavior
- it avoids reopening auth coordination and transport implementation at the same time
- it preserves current callers and tests as the useful floor

Next step:
- Task 19.9: implement the first SSH provider-policy split

## Task 19.10: re-scope the next infrastructure batch
Status: completed

Goal:
- choose the highest-value next infrastructure boundary after the first Docker, Kubernetes, and SSH splits

Candidates considered:
- deeper Docker parsing extraction
- deeper Kubernetes transport/parser split
- SSH runtime/failure-policy cleanup

Result:
- the next infrastructure seam should remain on SSH, specifically runtime/failure-policy cleanup

Why this wins:
- Docker now has a usable transport/failure seam and its remaining parsing tail is mostly local to one gateway
- Kubernetes now has a usable backend-policy seam and its remaining transport/parser tail is still narrower than the SSH ambiguity
- SSH still has broader cross-cutting infrastructure ambiguity around:
  - runtime cache ownership
  - provider-specific failure mapping
  - timeout/runtime variant behavior
  - capability-aware degradation ownership between infra and callers
- that makes SSH runtime/failure policy the stronger remaining system-wide seam

Next step:
- Task 19.11: define the SSH runtime/failure-policy target

## Task 19.11: define the SSH runtime/failure-policy target
Status: completed

Goal:
- describe what part of the current SSH path is runtime cache ownership, what part is provider-specific failure mapping, and what part is capability/degradation policy

Questions to answer:
- what should remain in `SshShellFactory`
- what should remain in provider-specific shell services
- what should move to a narrower runtime/failure seam
- what should remain feature-owned in callers

Done definition:
- the next SSH infra target is explicit
- one concrete implementation batch is chosen

Result:
- the next SSH infrastructure target is now explicit

### Current responsibility mix after the provider split

After `SshShellProviderSelector`, the remaining SSH ambiguity is concentrated in provider-specific runtime behavior:

1. runtime cache ownership
- `SshShellFactory` still owns cache lifecycle for builtin/process runtime instances
- timeout variants are still treated as special-case runtime instances inside the factory

2. provider-specific failure mapping
- `ProcessRemoteShellService` converts process exit patterns into generic auth/runtime exceptions inline
- `BuiltInRemoteShellService` and `BuiltInSshClientManager` surface builtin-specific exception types and timeout/auth behavior through a different path

3. capability/degradation policy
- higher layers still depend on uneven failure shapes depending on which provider is selected
- the boundary between infra failure classification and feature-level unavailable/error rendering is still not uniform enough

That is now the main SSH infrastructure smell.

### What should stay stable in the next SSH infra batch

These areas should stay stable for the first runtime/failure pass:
- feature call sites that consume `RemoteShellService`
- existing auth coordinator ownership and prompt gating
- transport implementations themselves (`ProcessSshRunner`, builtin client manager command execution)
- feature-level error wording and remediation decisions

Why they stay stable:
- the next batch should not reopen auth or transport implementation together with runtime failure policy
- the problem to solve now is failure-shape ownership, not terminal/editor UX

### Proposed target boundary

For the next pass, split the current SSH runtime responsibility into:
- runtime request/cache seam
  - keep `SshShellFactory` as the gateway, but make runtime cache keys and runtime kind explicit rather than implicit special cases
- failure classification seam
  - introduce one narrow SSH runtime failure shape that can represent:
    - auth failure
    - unavailable provider/runtime
    - timeout
    - generic command/runtime failure
- provider-specific adapters
  - builtin/process services convert their low-level failures into the shared runtime failure shape

### What should remain in `SshShellFactory` after the next pass

`SshShellFactory` should still own:
- `RemoteShellService` gateway API
- combining selector output with runtime construction/caching

It should not keep owning:
- ad hoc timeout/runtime variant cache branching
- implicit provider/runtime kind handling without explicit runtime request semantics

### What should remain feature-owned

Feature layers should still own:
- how SSH unavailable/auth/runtime failure states are surfaced to users
- whether a failure becomes a disabled action, banner, dialog, or breadcrumb
- domain-specific remediation wording

They should not need to know:
- whether failure came from builtin or process transport internals
- how provider-specific runtime exceptions are normalized
- how timeout/runtime variants are cached

### First implementation batch

The first SSH runtime/failure batch should extract:
- one explicit SSH runtime failure type
- one failure mapper/adaptor seam starting with `ProcessRemoteShellService`
- keep builtin exception behavior stable for now, but make the shared failure shape available so the second pass can converge builtin onto it

Runtime cache refactoring can stay inside `SshShellFactory` for this first failure batch.

Why this is the right cut:
- `ProcessRemoteShellService` is the smallest concrete failure-policy seam
- it starts normalizing provider-specific failure behavior without reopening builtin auth/runtime internals immediately
- it gives a shared failure vocabulary the rest of the SSH stack can converge on
- it avoids a broader rewrite of runtime caching and builtin transport in one step

Next step:
- Task 19.12: implement the first SSH runtime failure split

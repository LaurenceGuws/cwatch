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

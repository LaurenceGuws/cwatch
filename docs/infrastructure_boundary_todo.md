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
Status: pending

Goal:
- describe what part of the current Docker path is transport, what part is parsing, and what part is capability/degradation policy

Questions to answer:
- what should remain in `DockerClientService`
- what should move to a narrower transport or capability seam
- what should remain feature-owned in Docker views/controllers

Done definition:
- the first Docker infra boundary is explicit
- one concrete implementation batch is chosen

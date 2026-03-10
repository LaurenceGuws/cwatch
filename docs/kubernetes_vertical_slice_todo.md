# Kubernetes Vertical Slice TODO

Status: active
Purpose: define the fourth vertical slice after the explorer, Docker, and Server checkpoints, using the ownership, composition, capability, and testing groundwork already landed around the Kubernetes feature.

## Why Kubernetes Is Next

Kubernetes is the strongest next slice because:
- major groundwork already exists around:
  - runtime graph extraction
  - tab shell integration cleanup
  - command contribution cleanup
  - grouped Kubernetes settings ownership
  - capability-aware CLI/API degradation behavior
- `kubernetes_context_list.dart` still carries a mixed seam around:
  - context loading kickoff
  - placeholder/list hosting
  - command contribution
  - tab opening/replacement
  - dashboard entry orchestration
- it is the natural next proof after Servers because it exercises a feature with:
  - optional capability paths
  - placeholder-to-dashboard flow
  - module runtime ownership
  - lighter host/runtime complexity than Servers but richer dashboard behavior than Explorer

## Scope Of This Slice

This slice is not:
- a Kubernetes dashboard redesign
- a full CLI/API transport rewrite
- a generic cluster-management framework

This slice is:
- proving the next vertical-slice pass on a feature with placeholder, dashboard, and capability-aware module behavior
- reducing ambiguity in `kubernetes_context_list.dart` and adjacent Kubernetes workflow surfaces
- making Kubernetes runtime, context-list flow, and dashboard-opening ownership clearer end-to-end

## Current Architectural Starting Point

Relevant current files:
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
- [kubernetes_runtime.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_runtime.dart)
- [kubernetes_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_workspace_controller.dart)
- [kubernetes_context_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/kubernetes_context_controller.dart)
- [kubernetes_tab_builder.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_tab_builder.dart)
- [kubernetes_dashboard_view.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_dashboard_view.dart)
- [kubernetes_dashboard_service.dart](/home/home/personal/cwatch/lib/model/services_infra/kubernetes/kubernetes_dashboard_service.dart)

Current known truth:
- runtime ownership is materially cleaner than before
- capability degradation for missing/unavailable Kubernetes access is explicit enough to build on
- tab shell and generic tab command contribution cleanup already reduced shell noise
- the main remaining architectural weight is still concentrated in `kubernetes_context_list.dart`

## Task 18.1: confirm Kubernetes as the fourth vertical slice
Status: completed

Goal:
- choose the next true vertical slice after the Server checkpoint from current rewrite evidence

Candidates considered:
- kubernetes
- infrastructure policy cleanup

Result:
- Kubernetes is the fourth vertical slice

Why this wins:
- enough groundwork already exists to make the slice actionable
- it continues the feature-slice sequence before shifting back to broader infra policy work
- it exercises placeholder, capability, dashboard, and runtime ownership together without reopening the heaviest SSH complexity

## Task 18.2: define the Kubernetes target slice boundary
Status: completed

Goal:
- describe what this slice is allowed to change and what it should leave alone in the first pass

Questions to answer:
- what stays in the current Kubernetes runtime/service layer
- what should move out of `kubernetes_context_list.dart`
- what remains intentionally local to Kubernetes context-list and dashboard behavior in the first batch

Done definition:
- the slice boundary is explicit
- one concrete first implementation batch is chosen

Result:
- the first Kubernetes slice boundary is now explicit

### What stays stable / out of scope for the first batch

These areas should stay stable in the first Kubernetes slice pass:
- `KubernetesRuntime`
- `KubernetesContextController`
- `KubernetesWorkspaceController`
- `KubernetesTabBuilder`
- `kubernetes_dashboard_view.dart`
- `KubernetesDashboardService`
- current capability-aware missing/unavailable cluster behavior

Why they stay stable:
- runtime/composition and capability groundwork is already good enough to build on
- changing dashboard internals or transport/service behavior immediately would broaden the blast radius too early

### What stays intentionally local to Kubernetes behavior

These remain Kubernetes-local even after the first slice cut:
- context-list UI behavior
- dashboard UI behavior
- Kubernetes-specific action wording and remediation
- placeholder-to-dashboard semantics tied to kube contexts

The goal is not to genericize cluster dashboards or kube context selection.

### What should move out of `kubernetes_context_list.dart` first

The first seam is top-level Kubernetes workspace-shell orchestration around context loading and placeholder/list flow, not the dashboard view or the context rows themselves.

That means extracting the logic that currently coordinates:
- context loading kickoff and refresh
- settings-driven reload behavior
- command-palette and tab-navigation registration
- placeholder-tab creation/start-empty-tab helpers
- workspace-level context selection and placeholder replacement helpers

This should become a narrower Kubernetes workspace-shell seam, while context-list rendering and dashboard hosting stay local for now.

### Why this is the right first cut

- `kubernetes_context_list.dart` is still the main concentration point for mixed orchestration and rendering
- the most obvious seam is the Kubernetes shell around context loading, placeholder flow, and shell-level registrations
- it mirrors the same kind of top-level split that already proved useful in Docker and Servers
- it avoids prematurely splitting the denser context-list and dashboard behavior

## Task 18.3: implement Kubernetes top-level workspace-shell split
Status: completed

Goal:
- extract top-level Kubernetes workspace orchestration out of `kubernetes_context_list.dart` while leaving context list and dashboard behavior local for now

First code targets:
- context loading kickoff/refresh orchestration
- settings-driven context reload coordination
- command-palette and tab-navigation registration
- placeholder-tab creation/start-empty-tab helpers
- workspace-level context-selection replacement helpers

What should stay local in this batch:
- context row rendering
- collapsed-group and selection state
- dashboard widget composition
- Kubernetes-specific action wording and remediation

Done definition:
- `kubernetes_context_list.dart` is materially smaller and more focused on hosting/rendering
- the new seam clearly owns top-level Kubernetes module orchestration
- context list and dashboard behavior remain local and mostly untouched except where needed for the seam

Result:
- extracted [kubernetes_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_workspace_shell.dart)
- moved top-level Kubernetes workspace orchestration out of [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart):
  - context loading kickoff
  - settings-driven context reload coordination
  - command-palette registration/loading
  - tab-navigation registration
  - placeholder-tab creation/start-empty-tab flow
  - workspace-level context selection and placeholder replacement helpers
- kept these local to `kubernetes_context_list.dart`:
  - context row rendering
  - collapsed-group and selection state
  - dashboard widget composition
  - Kubernetes-specific action wording and remediation

## Task 18.4: re-scope the next Kubernetes slice batch
Status: pending

Goal:
- decide whether the next Kubernetes batch should deepen the regression floor around the new shell seam or extract another real Kubernetes-local seam

Questions to answer:
- is there another architectural seam in `kubernetes_context_list.dart`
- or is the remaining weight mostly true Kubernetes-local behavior that should stay together for now

Done definition:
- the next Kubernetes batch is explicit
- the choice is based on the post-split code shape, not file-length pressure

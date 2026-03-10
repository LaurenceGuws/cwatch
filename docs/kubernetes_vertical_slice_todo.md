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
Status: pending

Goal:
- describe what this slice is allowed to change and what it should leave alone in the first pass

Questions to answer:
- what stays in the current Kubernetes runtime/service layer
- what should move out of `kubernetes_context_list.dart`
- what remains intentionally local to Kubernetes context-list and dashboard behavior in the first batch

Done definition:
- the slice boundary is explicit
- one concrete first implementation batch is chosen

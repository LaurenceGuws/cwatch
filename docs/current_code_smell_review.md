# Current Code Smell Review

Status: active
Purpose: record the current repo-wide architecture and maintenance hotspots after the completed Docker, SSH, theme/token, StructuredDataTable, settings, file-operation UI, and config metadata cleanup passes.

## Summary

The repo's main problem is no longer broad boundary collapse.
The current problem is split ownership, repeated orchestration, and low-payoff indirection.

The earlier rewrite and hotspot passes materially improved:
- dependency direction
- composition root ownership groundwork
- settings taxonomy groundwork
- integration seams
- vertical slice boundaries
- infrastructure boundaries
- major Docker feature decomposition
- SSH runtime support extraction
- theme/token centralization
- StructuredDataTable engine projection splits

What remains is less about one giant file and more about architecture drift:
- runtime/composition ownership is still split across bindings, feature views, and feature-local controllers
- shared workflow patterns are still being rebuilt by hand
- some abstraction layers now look heavier than the problems they solve

## Current Highest-Value Hotspots

There is no single broad repo-wide cleanup hotspot left from the earlier review order.
The remaining work should reopen only from fresh evidence in concrete local seams.

## Current Design Checkpoint

The following earlier hotspots should now be treated as checkpointed current-state design, not as the active repo focus:
- Docker feature decomposition
- SSH runtime support decomposition
- SSH shell-factory/runtime-cache simplification
- file-operation UI deduplication
- config metadata single-source-of-truth cleanup
- UI-adapter surface reduction
- runtime/composition ownership cleanup
- workspace-shell hosting reuse
- SSH runtime/feature integration reevaluation
- file-operation flow reevaluation
- theme/token decomposition
- StructuredDataTable engine projection decomposition
- settings mutation ownership cleanup
- settings workflow reevaluation

What that means:
- those areas were materially improved and should remain enforced as the current baseline
- future work there should reopen from fresh evidence, not from the older hotspot ordering
- the active repo focus has shifted from giant subsystem files toward ownership clarity, DRY cleanup, and abstraction payoff

## Current Test-Risk View

The repo now has direct tests in many extracted seams, but the following still carry shared regression risk:
- workspace startup and restore flows across Docker, Server, and WSL
- settings mutation and persistence flows
- file-operation progress/cancellation behavior
- SSH provider selection and shell cache behavior

## Recommended Next Order

- reopen only from fresh evidence in a concrete local seam
- likely candidates, if evidence appears:
  - file-operation flow behavior
  - SSH runtime/feature integration
  - settings feature-local workflow

## Why This Order

### File-operation reevaluation
- the SSH and settings reevaluation seams are now checkpointed from the current code state
- file-operation flow behavior is still a plausible reopen candidate, but not an active rewrite mandate without fresh evidence

### Everything else only from fresh evidence
- narrower feature-local or file-operation flow work should now reopen only from fresh evidence

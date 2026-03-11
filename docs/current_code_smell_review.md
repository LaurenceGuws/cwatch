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

### 1. SSH runtime/feature integration reevaluation
Primary files:
- [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
- [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)

Why it matters now:
- the previous SSH runtime bulk and shell-factory indirection hotspots are materially reduced
- what remains is narrower runtime hosting and feature-integration behavior that should only be reopened from fresh evidence
- this is now the first active reevaluation seam in the current code state
### 2. File-operation flow reevaluation
Primary files:
- [file_operations_ui_handler.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operations_ui_handler.dart)
- [file_operation_transfer_session.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operation_transfer_session.dart)
- [file_operation_item_progress.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operation_item_progress.dart)
- [file_operation_transfer_runtime.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operation_transfer_runtime.dart)

Why it matters now:
- the main repeated transfer-UI scaffolding seam is materially reduced
- what remains is narrower flow-specific upload/download behavior that should only be reopened from fresh evidence
- this is a narrower reevaluation seam, not the clearest active DRY hotspot in the repo

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

1. SSH runtime/feature integration reevaluation only if fresh evidence reopens it
2. file-operation flow reevaluation only if fresh evidence reopens it

## Why This Order

### SSH reevaluation first
- the settings reevaluation cut is now checkpointed from the current code state
- SSH remains the next most plausible area where fresh evidence could still justify reopening a structural cleanup

### File-operation reevaluation after that
- narrower feature-local or file-operation flow work should now reopen only from fresh evidence

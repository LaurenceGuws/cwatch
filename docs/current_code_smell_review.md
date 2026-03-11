# Current Code Smell Review

Status: active
Purpose: record the current repo-wide architecture and maintenance hotspots after the completed Docker, SSH, theme/token, and StructuredDataTable cleanup passes.

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

### 1. Runtime and composition ownership blur
Primary files:
- [server_workspace_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/server_workspace_binding.dart)
- [docker_view_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/docker_view_binding.dart)
- [kubernetes_context_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/kubernetes_context_binding.dart)
- [server_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_controller.dart)
- [docker_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_workspace_controller.dart)

Why it matters now:
- feature runtime assembly is still split across `controller/di`, feature `view/` trees, and feature-local controllers
- persistence, restore logic, UI-adapter creation, and feature workflow ownership are not centered in one clear feature composition seam
- this is now the clearest decoupling problem in the current code state

### 2. Workspace-shell hosting duplication
Primary files:
- [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)

Why it matters now:
- the same workspace-shell setup pattern is still repeated across features
- tab restore/setup, listeners, placeholder/base-tab creation, and shell/runtime glue are still re-expressed per feature
- this is both a DRY problem and an ownership problem

### 3. File-operation UI flow duplication
Primary file:
- [file_operations_ui_handler.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operations_ui_handler.dart)

Why it matters now:
- progress dialog lifecycle, byte accounting, success/failure shaping, and cancellation behavior are still repeated across multiple flows
- changes to one operation path can still drift from the others

### 4. Config metadata abstraction drift
Primary files:
- [config_metadata_annotations.dart](/home/home/personal/cwatch/lib/model/config/config_metadata_annotations.dart)
- [config_metadata_descriptor.dart](/home/home/personal/cwatch/lib/model/config/config_metadata_descriptor.dart)
- [config_metadata_registry.dart](/home/home/personal/cwatch/lib/model/config/config_metadata_registry.dart)

Why it matters now:
- the repo pays for annotations, descriptors, and a handwritten registry at the same time
- that is a DRY failure unless one layer is the actual source of truth
- this subsystem is now a live over-engineering candidate

### 5. Controller to concrete UI-adapter coupling
Primary files:
- [settings_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/settings_controller.dart)
- [server_port_forward_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/server_port_forward_controller.dart)
- [docker_overview_actions_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/docker_overview_actions_controller.dart)
- [docker_overview_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/docker_overview_ui_adapter.dart)

Why it matters now:
- controller logic still depends on concrete dialog/snackbar/prompt adapters
- this is better than `model -> view` coupling, but still keeps workflow logic shaped around widget-era interaction seams

### 6. Feature-local settings workflow density
Primary files:
- [builtin_ssh_settings.dart](/home/home/personal/cwatch/lib/view/features/settings/settings/builtin_ssh_settings.dart)
- [ssh_settings_controls.dart](/home/home/personal/cwatch/lib/view/features/settings/settings/ssh_settings_controls.dart)
- [settings_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/settings_controller.dart)

Why it matters now:
- the repeated generic settings-tree mutation plumbing is materially reduced
- what remains is denser feature-local workflow around built-in SSH key management, host bindings, and picker/prompt orchestration
- this is now a narrower local complexity seam, not the same repo-level DRY hotspot as before

### 7. SSH runtime/feature integration reevaluation
Primary files:
- [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
- [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)

Why it matters now:
- the previous SSH runtime bulk and shell-factory indirection hotspots are materially reduced
- what remains is narrower runtime hosting and feature-integration behavior that should only be reopened from fresh evidence
- this is no longer a top repo-wide over-engineering target in the current code state

## Current Design Checkpoint

The following earlier hotspots should now be treated as checkpointed current-state design, not as the active repo focus:
- Docker feature decomposition
- SSH runtime support decomposition
- SSH shell-factory/runtime-cache simplification
- theme/token decomposition
- StructuredDataTable engine projection decomposition
- settings mutation ownership cleanup

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

1. Runtime/composition ownership cleanup
2. Workspace-shell hosting reuse
3. File-operation UI deduplication
4. Config metadata single-source-of-truth cleanup
5. UI adapter surface reduction
6. feature-local settings workflow reevaluation only if fresh evidence reopens it
7. SSH runtime/feature integration reevaluation only if fresh evidence reopens it

## Why This Order

### Runtime/composition ownership first
- it is the clearest remaining architecture smell
- it directly affects decoupling, disposal ownership, and feature-local reasoning

### Workspace-shell hosting second
- it is the strongest repeated workflow pattern left in the feature layer
- a cleaner host contract will reduce duplicate feature setup logic

### File operations third
- file-operation UI flow still has repeated orchestration risk
- it is now the clearest active DRY/behavior-drift risk after runtime and workspace hosting

### Config and UI-adapter work after that
- config metadata is a good candidate for de-complexing once the higher-value ownership seams are clearer
- controller/dialog adapter coupling is still a live structural smell once the stronger repetition seams are addressed

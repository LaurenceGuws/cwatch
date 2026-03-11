# Current Code Smell Review

Status: active
Purpose: replace earlier broad review assumptions with a fresh current-state hotspot map after the completed boundary, slice, infrastructure, and polish passes.

## Summary

The repo's main problem is no longer global boundary collapse.
The current problem is concentrated subsystem complexity.

The earlier rewrite layers materially improved:
- dependency direction
- composition root ownership
- settings taxonomy
- integration seams
- vertical slice boundaries
- infrastructure boundaries
- visible shared-shell polish

What remains is mostly concentrated in a smaller set of heavy subsystems and shared engines.

## Current Highest-Value Hotspots

### 1. Docker feature complexity
Primary files:
- [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart)
- [docker_overview.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_overview.dart)
- [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
- [docker_client_service.dart](/home/home/personal/cwatch/lib/model/features/docker/services/docker_client_service.dart)

Why it still matters:
- Docker remains the largest visible feature subsystem by concentrated file size and mixed responsibility.
- The feature has better ownership than before, but too much behavior still lives in a few large files.
- This is the best next feature-level cleanup target.

### 2. StructuredDataTable shared risk
Primary files:
- [structured_data_table.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table.dart)
- [structured_data_table_state.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_state.dart)
- [structured_data_table_rendering.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_rendering.dart)

Why it still matters:
- This is now effectively a shared UI engine, not a simple widget.
- It owns rendering, keyboarding, selection, hit testing, resizing, and context menus.
- The blast radius is high because many features depend on it.

### 3. SSH subsystem complexity
Primary files:
- [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
- [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)

Why it still matters:
- Boundary cleanup improved the subsystem, but it remains operationally dense.
- Provider selection, runtime caching, builtin/process differences, auth coordination, and failure mapping still create a high-complexity subsystem.
- This is now more of a subsystem-complexity problem than an ownership problem.

### 4. Theme/token centralization
Primary file:
- [app_theme.dart](/home/home/personal/cwatch/lib/model/shared/theme/app_theme.dart)

Why it still matters:
- Too many design concerns are centralized in one file.
- It works, but it is difficult to evolve safely because unrelated design primitives live together.

### 5. Active watchlist feature shells
Primary files:
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
- [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart)

Why they still matter:
- These are no longer architectural failures.
- They are still large enough to regress quickly if unchecked.
- They should be treated as watchlist files rather than immediate rewrite targets.

## Current Test-Risk View

The repo now has direct tests in the major new seams, but the following still carry higher shared risk than coverage depth suggests:
- `StructuredDataTable`
- deeper Docker list/overview behavior
- deeper SSH runtime behavior
- startup-order and lifecycle regressions in feature shells

## Recommended Next Order

1. Docker feature decomposition
2. StructuredDataTable risk reduction
3. SSH runtime simplification
4. Theme/token decomposition

## Why This Order

### Docker first
- highest remaining feature-level payoff
- strongest concentrated complexity hotspot
- likely to produce the clearest next structural win

### StructuredDataTable second
- highest remaining shared-engine risk
- easier to scope well after Docker clarifies what should stay feature-local vs table-engine-local

### SSH third
- still complex, but less entangled with day-to-day UI churn than Docker and the shared table engine

### Theme fourth
- important, but lower urgency than the two biggest runtime/feature hotspots

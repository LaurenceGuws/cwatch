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
- Recent passes removed real state, parser, and runtime knots, but too much behavior still lives in a few large files.
- This is still the clearest feature-level hotspot in the current code state.

### 2. SSH subsystem complexity
Primary files:
- [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
- [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)

Why it still matters:
- Boundary cleanup improved the subsystem, and the latest pass materially reduced builtin runtime bulk.
- The remaining SSH complexity is now concentrated more in shell-factory/runtime-cache semantics and builtin/process coordination than in one giant manager file.
- This is still a subsystem-complexity problem, but it is now much narrower than before.

### 3. Theme/token decomposition tail
Primary file:
- [app_theme.dart](/home/home/personal/cwatch/lib/model/shared/theme/app_theme.dart)

Why it still matters:
- The main theme/token centralization problem is no longer severe.
- What remains is mostly extension assembly and helper glue.
- Still worth future cleanup, but not the highest-value code-smell target anymore.

### 4. Active watchlist shell maintenance
Primary files:
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
- [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart)

Why it still matters:
- These are no longer architectural failures.
- Recent watchlist passes materially reduced the densest blocks in all three files.
- They still deserve attention during future feature work, but they are now maintenance-watch surfaces rather than top repo hotspots.

### 5. StructuredDataTable shared risk
Primary files:
- [structured_data_table.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table.dart)
- [structured_data_table_state.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_state.dart)
- [structured_data_table_rendering.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_rendering.dart)

Why it still matters:
- This is now effectively a shared UI engine, not a simple widget.
- It owns rendering, keyboarding, selection, hit testing, resizing, and context menus.
- The blast radius is high because many features depend on it.

Current checkpoint:
- projection logic has been split out
- shared table selection/right-click/hover behavior has been standardized
- cell navigation, cell selection, hit-test, resize, scroll, and reorder projection have been split out
- the remaining risk is now more about widget/rendering glue than pure engine complexity

## Current Test-Risk View

The repo now has direct tests in the major new seams, but the following still carry higher shared risk than coverage depth suggests:
- `StructuredDataTable`
- deeper Docker list/overview behavior
- deeper SSH runtime behavior
- startup-order and lifecycle regressions in feature shells

## Recommended Next Order

1. Docker feature decomposition
2. SSH runtime simplification
3. Theme/token decomposition

## Why This Order

### Docker first
- Docker is still the clearest remaining feature-level hotspot by raw file size and mixed responsibility.
- The groundwork is much better now, which makes a deeper cleanup more defensible instead of less.

### SSH second
- the latest SSH pass removed the densest builtin runtime knot
- SSH still matters, but its remaining hotspot is now narrower and more infrastructure-specific

### Theme third
- the current pass materially reduced centralization in [app_theme.dart](/home/home/personal/cwatch/lib/model/shared/theme/app_theme.dart)
- the remaining weight is smaller extension assembly and helper glue
- still worth future cleanup, but no longer the clearest immediate hotspot

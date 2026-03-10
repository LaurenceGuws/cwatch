# Settings State Taxonomy TODO

Status: active
Purpose: scope the next rewrite layer after composition ownership: separating persisted app settings, persisted workspace state, feature configuration, and widget-local state.

## Boundary This Hotspot Must Respect

The shell/framework may provide persistence infrastructure, but it should not force unrelated state into one global settings object.

This hotspot must also respect the strict workspace contract:
- the shell/framework enforces that each module has an initial placeholder tab state
- feature modules own the behavior of that placeholder state
- persisted workspace state is not the same thing as global app settings

## Current Problem

[app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart) currently mixes several different state categories:
- app-wide UI preferences
- shell/window preferences
- SSH and infrastructure configuration
- feature-specific preferences
- persisted workspace snapshots
- cached derived data such as distro maps
- settings-view UI state like selected tab index

That means one model currently acts as:
- persisted application settings
- workspace persistence container
- infra config store
- feature preference store
- UI session state bucket

This is the next structural source of coupling after the composition-root cleanup.

## Why This Matters

When unrelated state lives in one object:
- settings listeners become broad implicit event buses
- changes trigger cross-feature behavior accidentally
- persistence boundaries stay unclear
- rewrite work stalls because every feature touches the same root model

The problem is not just size.

The problem is taxonomy:
- what kind of state is this
- who owns it
- how long should it live
- where should it be persisted

## Working Rules For This Hotspot
- do not split `AppSettings` in code yet
- define the taxonomy first
- separate persisted workspace state from true application settings explicitly
- distinguish durable feature config from transient view state
- prefer one concrete taxonomy document over speculative multi-file redesigns

## First Batch Candidate

### Task 12.1: classify `AppSettings` fields by state type
Status: completed

Why this is first:
- the field list is already large enough to hide multiple ownership mistakes
- classification needs to be explicit before any safe split can happen
- this should produce a usable rewrite map without forcing code churn immediately

Current files in scope:
- `lib/model/models/app_settings.dart`
- `lib/model/services_infra/settings/app_settings_controller.dart`
- representative feature/settings call sites that show how settings are used today

Actions:
- classify each `AppSettings` field into a state category, for example:
  - app-wide preferences
  - shell/workspace chrome preferences
  - infrastructure configuration
  - feature-specific durable preferences
  - persisted workspace snapshots
  - cached derived data
  - transient view/session state
- identify which fields are in the wrong bucket today
- define what should remain in `AppSettings` versus what should move to dedicated models later
- record the smallest safe next code split

Done definition:
- every current `AppSettings` field is classified by state type
- the document makes clear which categories should be split out later
- the next code-facing split can be chosen from evidence rather than intuition

Verification:
- field taxonomy table exists in this document
- at least the major mixed categories are clearly separated in writing

### Task 12.2: re-scope after taxonomy classification
Status: completed

Purpose:
- choose the first real split candidate after classification
- likely candidates include:
  - workspace snapshots
  - shell/window preferences
  - infra configuration
  - settings-view state

Done definition:
- the first code split candidate is written from what Task 12.1 proves
- any category that must stay together temporarily is explicitly justified

Verification:
- follow-up task added before the next structural change starts

## Field Taxonomy

State categories used here:
- `app_pref`: durable application-wide preference
- `shell_pref`: durable shell/window/chrome preference
- `infra_config`: durable infrastructure/transport configuration
- `feature_pref`: durable feature-specific preference
- `workspace_snapshot`: persisted module workspace state
- `derived_cache`: persisted cache/derived lookup data
- `session_ui`: transient or weakly durable UI/session state that should not live in root settings long term

| Field | Category | Why |
| --- | --- | --- |
| `themeMode` | `app_pref` | global app theme preference |
| `debugMode` | `app_pref` | global debug/logging mode |
| `zoomFactor` | `app_pref` | global UI scaling preference |
| `appFontFamily` | `app_pref` | global typography preference |
| `appThemeKey` | `app_pref` | global app theme choice |
| `uiDensity` | `app_pref` | global density preference |
| `inputModePreference` | `app_pref` | app-wide input behavior preference |
| `shortcutBindings` | `app_pref` | app-wide shortcut customization |
| `windowUseSystemDecorations` | `shell_pref` | shell/window chrome behavior |
| `closeToTray` | `shell_pref` | shell/window lifecycle behavior |
| `shellSidebarWidth` | `shell_pref` | shell layout preference |
| `shellDestination` | `shell_pref` | shell navigation destination |
| `shellSidebarCollapsed` | `shell_pref` | shell chrome/layout state |
| `shellSidebarPlacement` | `shell_pref` | shell layout preference |
| `sshClientBackend` | `infra_config` | transport backend selection |
| `builtinSshHostKeyBindings` | `infra_config` | SSH key binding config |
| `customSshHosts` | `infra_config` | user-managed SSH host config |
| `customSshConfigPaths` | `infra_config` | SSH config source paths |
| `disabledSshConfigPaths` | `infra_config` | SSH config source filtering |
| `disabledServerHosts` | `infra_config` | host-level infra filtering |
| `kubernetesConfigPaths` | `infra_config` | kubeconfig source paths |
| `kubernetesBackend` | `infra_config` | Kubernetes transport/backend choice |
| `dockerRemoteHosts` | `infra_config` | remote docker host config |
| `serverAutoRefresh` | `feature_pref` | server feature behavior preference |
| `serverShowOffline` | `feature_pref` | server list presentation preference |
| `dockerSelectedContext` | `feature_pref` | docker feature durable selection/preference |
| `dockerLogsTail` | `feature_pref` | docker feature log behavior preference |
| `editorThemeLight` | `feature_pref` | editor feature preference |
| `editorThemeDark` | `feature_pref` | editor feature preference |
| `editorFontFamily` | `feature_pref` | editor feature preference |
| `editorFontSize` | `feature_pref` | editor feature preference |
| `editorLineHeight` | `feature_pref` | editor feature preference |
| `terminalFontFamily` | `feature_pref` | terminal feature preference |
| `terminalFontSize` | `feature_pref` | terminal feature preference |
| `terminalLineHeight` | `feature_pref` | terminal feature preference |
| `terminalPaddingX` | `feature_pref` | terminal feature preference |
| `terminalPaddingY` | `feature_pref` | terminal feature preference |
| `terminalThemeDark` | `feature_pref` | terminal feature preference |
| `terminalThemeLight` | `feature_pref` | terminal feature preference |
| `fileTransferUploadConcurrency` | `feature_pref` | file operation behavior preference |
| `fileTransferDownloadConcurrency` | `feature_pref` | file operation behavior preference |
| `explorerRowHeight` | `feature_pref` | explorer feature preference |
| `explorerShowBreadcrumbs` | `feature_pref` | explorer feature preference |
| `serverWorkspace` | `workspace_snapshot` | persisted server workspace state |
| `kubernetesWorkspace` | `workspace_snapshot` | persisted kubernetes workspace state |
| `wslWorkspace` | `workspace_snapshot` | persisted WSL workspace state |
| `dockerWorkspace` | `workspace_snapshot` | persisted docker workspace state |
| `serverDistroMap` | `derived_cache` | derived host distro cache |
| `dockerDistroMap` | `derived_cache` | derived container/host distro cache |
| `settingsTabIndex` | `session_ui` | settings-screen local navigation/session state |

## What Is In The Wrong Bucket Today

Clear taxonomy violations:
- `serverWorkspace`
- `kubernetesWorkspace`
- `wslWorkspace`
- `dockerWorkspace`
  - these are workspace persistence snapshots, not root application settings
- `serverDistroMap`
- `dockerDistroMap`
  - these are persisted derived caches, not user settings
- `settingsTabIndex`
  - this is settings-screen UI/session state, not root durable settings

Secondary tension areas:
- `shellSidebarWidth`
- `shellDestination`
- `shellSidebarCollapsed`
- `shellSidebarPlacement`
  - these are shell state/chrome preferences and likely deserve a shell-specific settings model later
- feature-pref clusters for editor/terminal/explorer/server/docker
  - these are durable, but the current root object is flattening unrelated feature concerns into one namespace

## What Should Likely Remain In Root App Settings

Reasonable root-level categories:
- app-wide preferences
- shell/window preferences
- infrastructure configuration

Meaning:
- `app_pref`
- `shell_pref`
- `infra_config`

These categories are still broad, but they at least belong at application scope.

## What Should Move Out Later

Strong split candidates:
- `workspace_snapshot`
  - should move to dedicated workspace persistence models/root container separate from app settings
- `derived_cache`
  - should move to dedicated cache persistence
- `session_ui`
  - should move to feature/view-local persistence or be allowed to remain transient

Later, but still likely:
- feature-specific durable preferences may eventually split into feature-scoped settings sections rather than one flat root model

## First Split Candidate

The first safe split candidate is:
- `workspace_snapshot`

Why this is first:
- it is already structurally separate data
- it directly intersects the strict placeholder-tab contract
- it is the clearest conceptual mismatch inside `AppSettings`
- Docker, Kubernetes, WSL, and Servers already treat these values as workspace persistence, not general settings

Follow-up split after that:
- `derived_cache`

Why not start with feature preferences:
- those are still durable settings and are less conceptually wrong than workspace snapshots
- splitting them first would create more design churn for less architectural clarity

## Result of Task 12.1

The main finding is:
- `AppSettings` is not primarily “too big”
- it is taxonomically mixed

The clearest hard boundary is:
- root application settings vs persisted workspace snapshots

That should drive the next code-facing split.

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 12.1 | AppSettings taxonomy | completed | every field is classified by state type |
| 12.4 | Workspace root seam | completed | workspace persistence flows through `PersistedWorkspaces` / `WorkspaceRootController` |
| 12.5 | Workspace storage split | completed | workspace snapshots persist through `workspaces.json` |
| 12.6 | Legacy workspace writes removed | completed | new `settings.json` writes no longer include workspace snapshots |

## Next Hotspot Scope

The next clearly wrong categories are now:
- `derived_cache`
  - `serverDistroMap`
  - `dockerDistroMap`
- `session_ui`
  - `settingsTabIndex`

Why these are next:
- workspace snapshots are now separated enough that they no longer dominate `AppSettings`
- the remaining wrong categories are small, explicit, and used through narrow seams
- this should let the next split stay surgical instead of turning into another root-model rewrite

### Task 12.7: scope derived-cache extraction
Status: completed

Goal:
- separate distro lookup caches from root application settings
- keep host/container distro consumers stable while changing the persistence owner

Known current seam:
- [host_distro_manager.dart](/home/home/personal/cwatch/lib/model/features/servers/services/host_distro_manager.dart)
- [container_distro_manager.dart](/home/home/personal/cwatch/lib/model/features/docker/services/container_distro_manager.dart)
- [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart)

What this task must answer:
- whether both distro maps should move into one generic cache root or one infra-specific cache model
- whether the read/write seam should live beside [workspace_storage.dart](/home/home/personal/cwatch/lib/model/services_infra/settings/workspace_storage.dart) or under the existing cache infrastructure
- how UI read sites should consume cache data without depending on `AppSettings`

Done definition:
- the target owner of `serverDistroMap` and `dockerDistroMap` is explicit
- the first code batch is scoped at the shared cache seam, not at random call sites
- the next implementation step is narrow enough to land without touching unrelated settings code

What landed:
- [distro_cache_controller.dart](/home/home/personal/cwatch/lib/model/services_infra/cache/distro_cache_controller.dart)
- [cache_storage.dart](/home/home/personal/cwatch/lib/model/services_infra/cache/cache_storage.dart) now supports string-map persistence
- [host_distro_manager.dart](/home/home/personal/cwatch/lib/model/features/servers/services/host_distro_manager.dart) now writes through the dedicated distro cache seam
- [container_distro_manager.dart](/home/home/personal/cwatch/lib/model/features/docker/services/container_distro_manager.dart) now writes through the dedicated distro cache seam
- server/docker UI read sites now consume the cache controller instead of reading distro maps from `AppSettings`

Result:
- distro lookup caches are now owned by cache infrastructure instead of root settings
- `serverDistroMap` and `dockerDistroMap` remain in [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart) only as migration seed data for the new cache controller
- this split stayed at the shared cache seam rather than turning into a UI rewrite

Verification:
- `flutter analyze`
- result: no issues found

### Task 12.9: remove legacy distro-cache fields from `AppSettings`
Status: completed

Goal:
- stop persisting `serverDistroMap` and `dockerDistroMap` in [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart)
- keep one-time migration from older embedded settings data while the new cache backing store takes over

Done definition:
- new `settings.json` writes no longer include distro maps
- cache hydration still recovers old embedded distro-map data if present
- server/docker consumers keep using the cache seam without further call-site changes

What landed:
- [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart) no longer serializes:
  - `serverDistroMap`
- `dockerDistroMap` was already no longer part of new `settings.json` writes by the time this cleanup landed
- legacy parsing remains in place so older embedded settings files still seed the distro cache controller

Result:
- new `settings.json` writes are now free of workspace snapshots and derived distro caches
- the cache backing store is now the authoritative write target for distro metadata
- legacy distro-map fields in `AppSettings` are reduced to migration-only compatibility data

Verification:
- `flutter analyze`
- result: no issues found

### Task 12.8: scope `settingsTabIndex` removal from root settings
Status: queued

Goal:
- remove settings-screen local tab/session state from `AppSettings`
- keep settings-screen behavior stable while moving this to feature-local persistence or transient state

Known current seam:
- [settings_view.dart](/home/home/personal/cwatch/lib/view/features/settings/settings/settings_view.dart)
- [settings_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/settings_controller.dart)
- [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart)

Why this should stay separate from derived-cache work:
- it is UI/session state, not infrastructure state
- combining them would blur the taxonomy again

Done definition:
- the replacement owner for `settingsTabIndex` is explicit
- it is clear whether this should be transient-only or lightly persisted feature-local state
- the follow-up code batch does not require changing unrelated settings persistence
| 12.2 | State-taxonomy re-scope | completed | first split candidate is chosen from the taxonomy |
| 12.3 | First split candidate | completed | workspace snapshot split is scoped into an executable next batch |

## Task 12.3 Result

The workspace-snapshot split should be staged around the existing persistence seam, not around feature views directly.

The existing seam already exists in:
- `WorkspacePersistence<T>`
- `PersistentWorkspaceController<TWorkspaceState>`
- feature workspace controllers that currently read/write workspace snapshots through `AppSettings`

That means the first code-facing split should not start by editing each feature screen.

It should start by changing the persistence contract from:
- `AppSettings` contains workspace snapshots

to:
- application settings and workspace snapshots are persisted as separate root concerns

## First Workspace-Snapshot Split Candidate

### Task 12.4: define a dedicated root workspace persistence container
Status: completed

Why this is next:
- workspace persistence already has a shared abstraction layer
- the main mismatch is the root container, not the feature controllers
- this is the narrowest split that respects the placeholder-tab contract and avoids feature-by-feature persistence churn first

Current files in scope:
- `lib/model/models/app_settings.dart`
- `lib/controller/core/workspace/workspace_persistence.dart`
- `lib/controller/core/workspace/persistent_workspace_controller.dart`
- representative workspace controllers:
  - `lib/view/features/servers/server_workspace_controller.dart`
  - `lib/view/features/docker/docker_workspace_controller.dart`
  - `lib/view/features/kubernetes/kubernetes_workspace_controller.dart`
  - `lib/controller/controllers/wsl_workspace_controller.dart`

Actions:
- define the target root model for persisted workspaces separate from `AppSettings`
- define how `WorkspacePersistence<T>` should read/write that root container instead of `AppSettings`
- define the minimum compatibility strategy so the split can land incrementally
- identify the first code batch that changes the persistence seam without redesigning all feature workspace controllers

Done definition:
- the dedicated workspace-persistence root container is described clearly
- the migration seam is identified at `WorkspacePersistence<T>` / `PersistentWorkspaceController<TWorkspaceState>`
- the next implementation batch can be chosen without guessing the whole persistence rewrite

Verification:
- the document names the new root persistence boundary explicitly
- the first code batch is framed at the shared persistence seam, not as scattered feature edits

## Dedicated Workspace Persistence Root

Target split:
- `AppSettings` should persist application settings only
- persisted module workspaces should move to a separate root persistence container

Proposed root container:

`PersistedWorkspaces`
- `server`
- `docker`
- `kubernetes`
- `wsl`

Possible shape:

```dart
class PersistedWorkspaces {
  const PersistedWorkspaces({
    this.server,
    this.docker,
    this.kubernetes,
    this.wsl,
  });

  final ServerWorkspaceState? server;
  final DockerWorkspaceState? docker;
  final KubernetesWorkspaceState? kubernetes;
  final WslWorkspaceState? wsl;
}
```

Root persistence direction:
- settings storage persists `AppSettings`
- workspace storage persists `PersistedWorkspaces`
- during the compatibility seam they may still mirror legacy embedded workspace fields
- but the physical workspace backing store should move to its own file

## Migration Seam

The correct migration seam is:
- `WorkspacePersistence<T>`
- `PersistentWorkspaceController<TWorkspaceState>`

Why:
- feature workspace controllers already centralize read/write behavior through this abstraction
- changing the root container here avoids feature-by-feature persistence rewrites first

Current assumption to remove:
- `WorkspacePersistence<T>` reads/writes workspace snapshots through `AppSettingsController`
- `PersistentWorkspaceController` requires:
  - `T? readFromSettings(AppSettings settings)`
  - `AppSettings writeToSettings(AppSettings current, T workspace)`

Target assumption:
- workspace persistence should read/write through a dedicated workspace root controller/storage
- feature workspace controllers should no longer need to know about `AppSettings` for persisted tab snapshots

## Minimum Compatibility Strategy

Do not split storage format and controller contracts in the same first code batch.

Staged path:

1. Introduce a dedicated workspace root model and controller/storage seam.
2. Teach `WorkspacePersistence<T>` to depend on that seam instead of `AppSettingsController`.
3. Keep temporary compatibility by allowing storage migration from existing `AppSettings` fields.
4. Update feature workspace controllers to read/write the new root container.
5. Remove workspace snapshot fields from `AppSettings` only after the new seam is live.

This keeps the placeholder-tab contract safe:
- feature workspace controllers still restore from their own workspace snapshots
- only the root persistence owner changes

## First Code Batch After This Doc

The first implementation batch should:
- introduce `PersistedWorkspaces`
- introduce a dedicated workspace persistence controller/storage abstraction
- refit `WorkspacePersistence<T>` to use that abstraction
- avoid removing fields from `AppSettings` yet

That is the narrowest shared-seam change that moves the architecture forward without breaking all workspace restore paths at once.

## Task 12.4 Checkpoint

Status: completed

What landed:
- [persisted_workspaces.dart](/home/home/personal/cwatch/lib/model/models/persisted_workspaces.dart)
- [workspace_root_controller.dart](/home/home/personal/cwatch/lib/model/services_infra/settings/workspace_root_controller.dart)
- [workspace_persistence.dart](/home/home/personal/cwatch/lib/controller/core/workspace/workspace_persistence.dart)
- [persistent_workspace_controller.dart](/home/home/personal/cwatch/lib/controller/core/workspace/persistent_workspace_controller.dart)

What changed:
- workspace persistence now reads and writes through `WorkspaceRootController`
- the root workspace container is now explicit as `PersistedWorkspaces`
- docker, kubernetes, WSL, and server workspace controllers now persist through that seam instead of directly through `AppSettings`
- feature views now compare persisted workspace signatures through `workspacePersistence.read()` instead of directly reading `settings.*Workspace`

What did not change yet:
- legacy workspace snapshot fields still exist in [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart) for compatibility
- `serverWorkspace`, `dockerWorkspace`, `kubernetesWorkspace`, and `wslWorkspace` have not been removed from [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart)
- physical storage separation has not landed yet

Why this is the right checkpoint:
- the shared persistence seam changed first
- placeholder-tab restore behavior stayed feature-owned
- future storage migration can now happen behind the seam instead of inside feature modules

Verification:
- `flutter analyze`
- result: no issues found

## Next Batch Candidate

### Task 12.5: separate physical storage from `AppSettings`
Status: completed

Goal:
- move workspace snapshot storage behind a dedicated persistence backing store
- keep the compatibility seam stable while storage ownership changes underneath it

Likely scope:
- settings serialization/loading code
- `AppSettingsController` interaction boundaries
- migration fallback from old embedded workspace snapshots to the new workspace root storage

Done definition:
- `WorkspaceRootController` no longer depends on workspace snapshots being embedded in `AppSettings`
- old embedded workspace fields are only used for migration or are removed entirely
- feature workspace controllers remain unchanged across that storage move

What landed:
- [workspace_storage.dart](/home/home/personal/cwatch/lib/model/services_infra/settings/workspace_storage.dart)
- [workspace_root_controller.dart](/home/home/personal/cwatch/lib/model/services_infra/settings/workspace_root_controller.dart) now loads and saves `workspaces.json`
- [persisted_workspaces.dart](/home/home/personal/cwatch/lib/model/models/persisted_workspaces.dart) now owns JSON serialization for the dedicated workspace root
- workspace restore paths now await the workspace root load through [workspace_persistence.dart](/home/home/personal/cwatch/lib/controller/core/workspace/workspace_persistence.dart)

Result:
- workspace snapshots now have a dedicated physical backing store
- legacy embedded workspace fields remain only as migration fallback data
- feature workspace controllers did not need another ownership rewrite

Verification:
- `flutter analyze`
- result: no issues found

### Task 12.6: remove legacy embedded workspace fields from `AppSettings`
Status: completed

Goal:
- stop serializing workspace snapshots in [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart)
- keep one-time migration from legacy embedded fields if old settings files are present

Likely scope:
- `app_settings.dart`
- `settings_storage.dart`
- `workspace_storage.dart`
- compatibility migration rules between old `settings.json` and new `workspaces.json`

Done definition:
- new writes to `settings.json` no longer include workspace snapshots
- startup can still recover workspaces from older embedded settings files
- all workspace restore behavior still flows through `WorkspaceRootController`

What landed:
- [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart) no longer serializes:
  - `serverWorkspace`
  - `kubernetesWorkspace`
  - `wslWorkspace`
  - `dockerWorkspace`
- legacy parsing remains in place so older `settings.json` files still load embedded workspace snapshots for migration fallback

Result:
- new `settings.json` writes are now application-settings only
- `workspaces.json` is the authoritative write target for workspace snapshots
- compatibility with older embedded settings files remains intact

Verification:
- `flutter analyze`
- result: no issues found

## Completion Metric

This document is serving its purpose if:
- it turns the vague “AppSettings is too big” complaint into an explicit ownership map
- it separates persisted workspace state from actual application settings
- it gives the next split step a concrete basis instead of guesswork

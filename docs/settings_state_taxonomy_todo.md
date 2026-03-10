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
| 12.2 | State-taxonomy re-scope | completed | first split candidate is chosen from the taxonomy |
| 12.3 | First split candidate | queued | workspace snapshot split is scoped into an executable next batch |

## Completion Metric

This document is serving its purpose if:
- it turns the vague “AppSettings is too big” complaint into an explicit ownership map
- it separates persisted workspace state from actual application settings
- it gives the next split step a concrete basis instead of guesswork

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
Status: queued

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
Status: queued

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

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 12.1 | AppSettings taxonomy | queued | every field is classified by state type |
| 12.2 | State-taxonomy re-scope | queued | first split candidate is chosen from the taxonomy |

## Completion Metric

This document is serving its purpose if:
- it turns the vague “AppSettings is too big” complaint into an explicit ownership map
- it separates persisted workspace state from actual application settings
- it gives the next split step a concrete basis instead of guesswork

# Feature UI Adapter Ownership TODO

Status: active
Purpose: scope the remaining adapter-side ownership seam now that the broad dependency-direction cleanup has removed the major cross-layer reversals.

## Boundary This Hotspot Must Respect

Shared shell/framework UI may stay reusable and concrete.

That includes things like:
- generic dialog wrappers
- keyboard shortcut shells
- shared progress popups
- reusable port-forward dialogs

Those are not the same problem as feature-specific UI adapters.

Feature-specific UI adapters that depend on feature-local dialogs or feature-local presentation should live with the feature module, not in a generic `controller/adapters` bucket that reads like reusable app infrastructure.

## Current Problem

The remaining `controller -> view` imports are now concentrated in UI adapters.

Most are acceptable shared-shell UI dependencies:
- `dialog_keyboard_shortcuts.dart`
- `port_forward_dialog.dart`
- `file_operation_progress_dialog.dart`
- `operation_progress_popup.dart`
- `remote_file_info_dialog_content.dart`
- explorer shared dialog widgets

The clearest remaining ownership problem is narrower:
- [server_workspace_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/server_workspace_ui_adapter.dart)
  imports
  [add_server_dialog.dart](/home/home/personal/cwatch/lib/view/features/servers/servers/add_server_dialog.dart)

That is a feature-specific dialog seam, not shared-shell UI.

## Why This Matters

At this point the repo needs to stop treating all adapter-side widget imports as suspicious.

The useful rule is:
- shared-shell UI can remain shared and concrete
- feature-specific UI adapters should live with the feature module or behind an explicit feature contract

This hotspot is about making that last distinction visible in the codebase.

## Working Rules For This Hotspot
- do not abstract shared dialogs just to avoid concrete imports
- do not move generic reusable widgets out of shared-shell ownership
- focus on feature-specific adapters that still read like generic controller infrastructure
- prefer one narrow ownership correction over a broad adapter package redesign
- re-scope after the first move

## First Batch Candidate

### Task 10.1: reclassify server workspace UI adapter ownership
Status: queued

Why this is first:
- it is the clearest remaining feature-specific adapter seam
- the adapter already knows server-specific dialog flows
- the current location under `controller/adapters` is more misleading than the dependency itself

Current files in scope:
- `lib/controller/adapters/server_workspace_ui_adapter.dart`
- `lib/view/features/servers/servers/add_server_dialog.dart`
- `lib/view/features/servers/server_workspace_view.dart`
- any directly related server feature wiring needed to clarify ownership

Actions:
- inspect whether `ServerWorkspaceUiAdapter` is feature-module UI code rather than reusable controller infrastructure
- move it to the server feature module if that classification holds
- keep shared UI widget dependencies where they are if they are genuinely reusable
- record what remains after this move

Done definition:
- the server feature-specific UI adapter no longer reads like generic controller infrastructure
- the remaining adapter-side shared-widget imports are more clearly intentional shared-shell UI usage
- the next cleanup step, if any, is evidence-driven rather than category confusion

Verification:
- `rg -n "package:cwatch/view/features/" lib/controller/adapters`
- `flutter analyze`
- manual smoke check of server rename/add/port-forward dialogs

### Task 10.2: re-scope after server UI adapter reclassification
Status: queued

Purpose:
- decide whether another feature-specific adapter should move
- or stop this hotspot and explicitly record the remaining shared-widget imports as acceptable shell/framework UI dependencies

Done definition:
- the next step is written from what Task 10.1 proves
- any acceptable remaining adapter-side exceptions are recorded here

Verification:
- follow-up task added before the next structural change starts

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 10.1 | Server UI adapter ownership | queued | feature-specific server UI adapter ownership is clearer than today |
| 10.2 | Adapter hotspot re-scope | queued | next step is written from what 10.1 proves |

## Completion Metric

This document is serving its purpose if:
- it separates acceptable shared-shell UI usage from real feature-specific ownership problems
- it avoids over-cleaning the remaining adapter imports
- it gives one narrow, actionable next step with a clear done condition

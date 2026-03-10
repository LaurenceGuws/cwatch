# Theme Registry Ownership TODO

Status: active
Purpose: scope the remaining shared-theme ownership seam where non-UI theme/config code still lives under an editor view path and leaks into `model/` and other shared tabs.

## Boundary This Hotspot Must Respect

Shared theme registries, theme-option catalogs, and config validation logic are reusable shell/framework concerns.

They are not:
- remote-editor-specific view composition
- feature-module-owned UI
- tab-local helper code

If theme metadata is needed by model/config loading, editor tabs, and terminal/shared tabs, it should not live under a remote editor view subtree.

## Current Problem

The strongest remaining wrong-direction dependency is:
- [theme_config_loader.dart](/home/home/personal/cwatch/lib/model/shared/theme/theme_config_loader.dart) importing [editor_theme_utils.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/editor/remote_file_editor/editor_theme_utils.dart)

There is also a broader ownership signal:
- terminal/shared tab code also imports the same editor-local theme helper
- the helper appears to mix reusable theme registry data with editor-facing naming/styling access

This means a shared theme registry is currently mislocated under a view-local editor path.

## Why This Matters

This is no longer a feature-module boundary problem.

It is now a reusable shell/framework ownership problem:
- model/config code should not depend on a view-local editor helper
- shared theme catalogs should be neutral infrastructure
- view code can depend on that shared registry, not the other way around

## Working Rules For This Hotspot
- do not redesign the full theming system
- extract only the reusable theme registry/catalog and validation surface
- keep editor-specific presentation helpers with the editor if they are truly editor-only
- prefer one neutral shared location over more wrapper/re-export files
- re-scope after the first extraction lands

## First Batch Candidate

### Task 9.1: extract shared editor-theme registry out of the editor view tree
Status: completed

Why this is first:
- it is the clearest remaining `model -> view` import
- the shared usage pattern already proves the current location is wrong
- it should be a narrow move with low behavioral risk

Current files in scope:
- `lib/model/shared/theme/theme_config_loader.dart`
- `lib/view/shared/views/shared/tabs/editor/remote_file_editor/editor_theme_utils.dart`
- `lib/view/shared/views/shared/tabs/editor/remote_file_editor_tab.dart`
- `lib/view/shared/views/shared/tabs/editor/remote_file_editor/theme_picker.dart`
- `lib/view/shared/views/shared/tabs/terminal/terminal_theme_presets.dart`

Actions:
- inspect which parts of `editor_theme_utils.dart` are reusable theme registry/catalog logic
- move that reusable part to a neutral shared theme location
- update model/shared/view imports to use the new shared location
- record whether any editor-only helper remains behind

Done definition:
- `lib/model/shared/theme/theme_config_loader.dart` no longer imports from `view/`
- shared theme registry/catalog code no longer lives under the remote-editor view subtree
- remaining editor-local theme helpers, if any, are explicitly editor-only

Verification:
- `rg -n "editor_theme_utils.dart|package:cwatch/view/" lib/model/shared/theme lib/view/shared/views/shared/tabs/(editor|terminal)`
- `flutter analyze`
- manual smoke check of theme config loading and editor theme selection

### Task 9.2: re-scope after shared theme extraction
Status: completed

Purpose:
- decide whether there is another theme/shared-config ownership seam worth cleaning now
- or stop this hotspot once the mislocated shared registry is fixed

Done definition:
- the next theme/shared ownership step is written from what Task 9.1 proves
- any remaining editor-only exception is recorded here

Verification:
- follow-up task added before the next structural change starts

Result of Task 9.1:
- the reusable editor theme catalog/registry moved to `lib/model/shared/theme/editor_theme_registry.dart`
- `theme_config_loader.dart` no longer imports from `view/`
- editor and terminal shared tabs now depend on the neutral shared-theme location instead of an editor-local file
- there was no meaningful editor-only logic left behind in the old file; it was shared registry code end to end

### Theme-registry hotspot checkpoint
Status: completed

Outcome:
- the strongest remaining `model -> view` theme dependency is removed
- shared theme registry ownership is now aligned with reusable shell/framework concerns
- this hotspot does not need another immediate batch unless a different shared-theme seam appears later

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 9.1 | Shared theme registry extraction | completed | model/shared theme loading no longer depends on an editor view path |
| 9.2 | Theme hotspot re-scope | completed | next step is written from what 9.1 proves |
| 9.3 | Theme-registry checkpoint | completed | shared theme registry ownership is clear enough to stop this hotspot |

## Completion Metric

This document is serving its purpose if:
- it isolates the remaining shared-theme ownership problem clearly
- it removes a real `model -> view` dependency rather than inventing a larger theme rewrite
- it gives us one narrow next step with a clear done condition

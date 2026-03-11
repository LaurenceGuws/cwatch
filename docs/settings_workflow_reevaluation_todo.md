# Settings Workflow Reevaluation TODO

Status: active
Purpose: track bounded reevaluation work in the remaining settings-specific workflow seams after the generic settings mutation cleanup pass was checkpointed.

## Task 27.1: start the settings workflow reevaluation pass
Status: completed

Goal:
- reopen settings work only from fresh evidence in the current code state
- keep this pass focused on remaining workflow-density and ownership blur, not on the already-completed generic mutation cleanup

Done definition:
- there is one active TODO for the narrowed settings reevaluation pass
- the first bounded batch is named from the current built-in SSH workflow state

Result:
- settings workflow reevaluation is now the active top reevaluation seam
- the first bounded batch should come from the built-in SSH settings flow

## Task 27.2: define the first bounded settings reevaluation batch
Status: completed

Goal:
- choose one concrete ownership seam in the built-in SSH settings flow
- keep the batch on real controller/widget coupling rather than broad settings redesign

Done definition:
- one explicit first batch is named
- the stop condition reflects the current code shape

Result:
- the first bounded settings reevaluation batch is now:
  - narrow built-in SSH settings to the dedicated key workflow controller surface
- target files:
  - [builtin_ssh_settings.dart](/home/home/personal/cwatch/lib/view/features/settings/settings/builtin_ssh_settings.dart)
  - [ssh_settings_controls.dart](/home/home/personal/cwatch/lib/view/features/settings/settings/ssh_settings_controls.dart)
  - [settings_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/settings_controller.dart)
  - [built_in_ssh_key_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/built_in_ssh_key_controller.dart)
- stop condition:
  - the built-in SSH settings widget no longer depends on the broad settings controller for key-vault operations
  - host-binding ownership lives with the key workflow controller instead of a pass-through layer
  - behavior stays stable

Why this is the right first cut:
- the generic mutation-plumbing hotspot is already reduced and checkpointed
- the clearest remaining settings smell is local ownership blur in the built-in SSH flow
- this addresses real controller/widget coupling without reopening settled settings architecture work

## Task 27.3: implement the first bounded settings reevaluation batch
Status: completed

Goal:
- narrow the built-in SSH settings UI to the dedicated key workflow surface
- remove obsolete pass-through API from the broad settings controller

Done definition:
- built-in SSH settings depend on the dedicated key controller plus the specific SSH preference data they actually render
- settings controller no longer re-exposes the built-in SSH key workflow as pass-through methods
- focused key-controller coverage reflects the narrower ownership split

Result:
- the built-in SSH settings widget now depends on:
  - [built_in_ssh_key_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/built_in_ssh_key_controller.dart)
  - [ssh_preferences.dart](/home/home/personal/cwatch/lib/model/models/ssh_preferences.dart)
- the narrowed UI surface is wired from:
  - [ssh_settings_controls.dart](/home/home/personal/cwatch/lib/view/features/settings/settings/ssh_settings_controls.dart)
- the broad pass-through API was removed from:
  - [settings_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/settings_controller.dart)
- focused coverage now includes host-binding ownership in:
  - [built_in_ssh_key_controller_test.dart](/home/home/personal/cwatch/test/controller/controllers/built_in_ssh_key_controller_test.dart)

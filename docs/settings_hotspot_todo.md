# Settings Hotspot TODO

Status: active
Purpose: track bounded cleanup batches for the current settings mutation and composition hotspot.

## Task 26.1: start the settings hotspot pass
Status: completed

Goal:
- treat settings mutation/composition cleanup as the next active repo hotspot after the runtime/composition checkpoint
- keep this pass focused on ownership clarity and DRY cleanup, not on replacing the whole settings surface

Done definition:
- there is one active settings TODO for the new pass
- the first bounded batch is named from the current code state

Result:
- settings mutation/composition cleanup is now the active hotspot pass
- the first bounded batch should reduce UI-owned settings-tree mutation knowledge without reopening checkpointed runtime, Docker, SSH, theme, or table internals

## Task 26.2: define the first bounded settings batch
Status: completed

Goal:
- choose one concrete settings cleanup slice with strong DRY and decoupling value
- keep the first batch on mutation ownership rather than broad visual redesign

Done definition:
- one first batch is explicit
- the stop condition is clear from the current code shape

Result:
- the first bounded settings batch is now:
  - move general, terminal, editor, and Docker settings update semantics out of `settings_view.dart`
- target files:
  - [settings_view.dart](/home/home/personal/cwatch/lib/view/features/settings/settings/settings_view.dart)
  - [settings_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/settings_controller.dart)
  - new settings mutation support under `lib/controller/controllers/`
- stop condition:
  - `settings_view.dart` no longer owns repeated nested preference-tree `copyWith` chains for those sections
  - settings update semantics are centered in the settings controller seam
  - focused regression coverage exists for the extracted mutation support

Why this is the right first cut:
- `settings_view.dart` is still the clearest place where the UI knows too much about persisted settings structure
- terminal and editor preferences contain the most visible nested mutation duplication
- this reduces coupling and repetition without introducing a speculative settings-form framework

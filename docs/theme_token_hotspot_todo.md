# Theme Token Hotspot TODO

Status: active
Purpose: track the current theme/token decomposition pass after the fresh current-state review.

## Task 24.1: start the theme/token hotspot pass
Status: completed

Goal:
- treat theme/token decomposition as the first active hotspot from the fresh current-state review
- keep this pass focused on token-family organization, not visual redesign

Done definition:
- there is one theme-only TODO for the new pass
- the first bounded theme batch is named

Result:
- theme/token decomposition is now the active current-state hotspot
- the first bounded batch should reduce centralization in `app_theme.dart` without changing the public theme surface

## Task 24.2: define the first bounded theme batch
Status: completed

Goal:
- choose one concrete token decomposition slice with strong value and low ambiguity

Done definition:
- one first batch is explicit
- the batch has a clear stop condition
- later theme concerns remain queued instead of over-planned

Result:
- the first bounded theme batch is now:
  - token-family extraction from `app_theme.dart`
- target files:
  - [app_theme.dart](/home/home/personal/cwatch/lib/model/shared/theme/app_theme.dart)
  - new token-family files under `lib/model/shared/theme/tokens/`
- stop condition:
  - list, section, tab-chip, icon/dimension, docker, and distro token families no longer live inline in `app_theme.dart`
  - the public `AppThemeTokens` surface stays stable
  - no visual behavior changes are introduced in this batch

## Queued Next Batches

These are intentionally not yet active:
- typography and spacing decomposition cleanup
- theme factory / settings seam cleanup
- dynamic spacing and zoom-policy cleanup
- theme docs/descriptor cleanup

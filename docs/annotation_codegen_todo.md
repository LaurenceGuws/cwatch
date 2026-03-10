# Annotation Codegen TODO

Status: active
Purpose: scope the first annotation/codegen batch from stable metadata instead of hand-wired runtime behavior.

## Why This Is Next

The current integration-smell checkpoints are strong enough now:
- tab shell contract is explicit
- dialog/settings prompt contract is explicit
- SSH auth ownership is at a good checkpoint
- explorer shared surface is explicit and checkpointed

That means the next useful question is no longer a shell polish question.

It is:
- which metadata is stable enough to become declarative
- and which metadata should stay in explicit runtime code

This is the right time to answer that because:
- the main shared UI contracts are clearer
- we can now distinguish stable metadata from active behavior
- codegen can be evaluated as an integration cleanup tool rather than as framework hype

## Rule For This Hotspot

Annotations/codegen are only valid for stable metadata.

Good targets:
- config/schema metadata
- command registration metadata
- context-menu contribution metadata
- tab/view descriptor metadata
- capability declaration metadata

Bad targets:
- controller lifecycle
- runtime graph construction
- async workflow policy
- dialog flow orchestration
- feature-specific placeholder-tab behavior

## Candidate Ranking

### Candidate 1: config/schema metadata
Why it is strongest:
- highest stability
- already partly normalized through grouped preferences
- useful for settings docs, schema generation, and later Lua exposure
- low risk of hiding runtime behavior

Likely model files:
- [app_settings.dart](/home/home/personal/cwatch/lib/model/models/app_settings.dart)
- [shell_preferences.dart](/home/home/personal/cwatch/lib/model/models/shell_preferences.dart)
- [editor_preferences.dart](/home/home/personal/cwatch/lib/model/models/editor_preferences.dart)
- [terminal_preferences.dart](/home/home/personal/cwatch/lib/model/models/terminal_preferences.dart)
- [explorer_preferences.dart](/home/home/personal/cwatch/lib/model/models/explorer_preferences.dart)
- [ssh_preferences.dart](/home/home/personal/cwatch/lib/model/models/ssh_preferences.dart)
- [kubernetes_preferences.dart](/home/home/personal/cwatch/lib/model/models/kubernetes_preferences.dart)
- [docker_preferences.dart](/home/home/personal/cwatch/lib/model/models/docker_preferences.dart)

What codegen could realistically produce first:
- config key descriptors
- grouped settings schema/export docs
- UI descriptor metadata for settings sections
- Lua-facing config metadata later

### Candidate 2: capability declaration metadata
Why it is promising:
- the repo already has an explicit capability/degradation rule
- missing CLI and optional integration breadcrumbs are now documented product policy
- capability metadata is stable enough to be declared

Why it should wait:
- current capability checks are still distributed enough that metadata would outrun the actual capability seam
- easier to abuse into runtime magic too early

### Candidate 3: command/menu registration metadata
Why it is promising:
- there is real hand-wired command/context-menu integration in the shell
- could reduce repetitive menu/command glue later

Why it should wait:
- command ownership is not as stable as config ownership yet
- likely to blur into runtime behavior if started too early

### Candidate 4: tab/view descriptor metadata
Why it is tempting:
- placeholder-tab rule and tab shell contract are now explicit

Why it should wait:
- tab runtime behavior is still too close to real workflow code
- too much risk of framework sludge if descriptor metadata grows too early

## Recommendation

The first annotation/codegen target should be:
- config/schema metadata

Specifically:
- grouped settings/preferences models
- not views
- not controllers
- not tab runtime behavior

That gives the repo the cleanest proof point for annotation-driven integration.

## Task 14.31: choose the first annotation/codegen target
Status: completed

Goal:
- select the first metadata seam that is stable enough for declarative annotations/codegen

Done definition:
- one candidate is explicitly chosen
- weaker candidates are explicitly deferred
- the choice is justified by current repo state rather than abstraction preference

Result:
- the first target is config/schema metadata around grouped settings/preferences models
- capability, command/menu, and tab descriptor metadata remain queued later candidates

## Task 14.32: scope config/schema annotation metadata
Status: completed

Goal:
- define the smallest first annotation/codegen slice around settings/preferences metadata without touching runtime behavior

Candidates considered:
- annotate every grouped preference model immediately
- start with only primitive grouped preference models
- start at `AppSettings` root section metadata only

Decision:
- the first codegen slice should target the primitive grouped preference models first:
  - [shell_preferences.dart](/home/home/personal/cwatch/lib/model/models/shell_preferences.dart)
  - [editor_preferences.dart](/home/home/personal/cwatch/lib/model/models/editor_preferences.dart)
  - [terminal_preferences.dart](/home/home/personal/cwatch/lib/model/models/terminal_preferences.dart)
  - [explorer_preferences.dart](/home/home/personal/cwatch/lib/model/models/explorer_preferences.dart)

Why this is the right first cut:
- these models are already cohesive and stable
- their fields are mostly scalar config values with straightforward keys/defaults
- they are enough to prove schema/descriptor generation without dragging in richer domain types
- they keep the first pass focused on metadata, not serialization edge cases

Why the other candidates wait:
- `ssh_preferences.dart`
  - includes nested host/config collections and backend-specific concerns
- `kubernetes_preferences.dart`
  - smaller, but tied to enum/backend semantics better handled after the primitive proof point
- `docker_preferences.dart`
  - simple enough later, but less foundational than shell/editor/terminal/explorer
- `AppSettings` root metadata first
  - too high-level for the first proof point and too easy to over-design

Proposed first outputs:
- generated config field descriptors
- generated grouped schema/export metadata
- generated default/value documentation surface

Explicit anti-goals:
- no generated runtime update logic
- no generated settings UI widgets
- no reflection-like controller wiring
- no attempt to describe feature workflow behavior

Done definition:
- one narrow metadata slice is chosen
- proposed outputs are concrete
- anti-goals are explicit so the first codegen pass stays narrow

Result:
- the first codegen proof point is now explicitly primitive grouped preference metadata
- the next batch should define the annotation shape, not implement broad codegen

## Task 14.33: define config metadata annotation shape
Status: completed

Goal:
- define the smallest annotation surface needed to describe config keys/defaults/docs for the first grouped preference models

Decision:
- use one narrow annotation family with two annotations:
  - `@ConfigGroup(...)` on the preferences class
  - `@ConfigField(...)` on individual fields

Required `ConfigGroup` metadata:
- persistent group key
- human label
- short description
- optional display/order hint for generated docs

Required `ConfigField` metadata:
- persistent config key within the group
- human label
- short description/help text
- value kind hint:
  - string
  - boolean
  - integer
  - double
  - enum
- optional unit hint where useful
- optional default-value documentation override when the constructor default is not enough

Explicitly deferred field metadata:
- reload impact metadata such as:
  - immediate
  - hot-reload-safe
  - full-app-restart-required

Why deferred:
- it is useful metadata, especially for settings UX and dev tooling
- but it should be added only after the first descriptor output exists
- otherwise the first pass will start encoding runtime/app-lifecycle behavior too early

Deliberately excluded from the first shape:
- runtime validators
- visibility conditions
- controller bindings
- widget classes
- command handlers
- side effects
- async loaders

Why this is the right first shape:
- enough to generate descriptors and schema/docs
- small enough to keep runtime behavior explicit
- compatible with later Lua/config export use without forcing UI generation now

First implementation target after this:
- annotate the four primitive grouped preference models only
- generate one descriptor/registry output from them

Done definition:
- the annotation shape is explicit
- required metadata fields are explicit
- the first implementation slice is still narrow enough to prove the pattern without framework sludge

Result:
- the first annotation family is now defined tightly enough to implement without ambiguity
- the next batch should create the annotation types and first descriptor output, not expand the scope

## Task 14.34: implement config metadata annotations
Status: completed

Goal:
- add the first narrow annotation family and use it on the primitive grouped preference models

Expected scope:
- define `ConfigGroup` and `ConfigField`
- annotate shell/editor/terminal/explorer preference models
- add one generated or generator-ready descriptor surface target

Done definition:
- annotation types exist
- the four primitive grouped preference models are annotated
- the first output target is explicit and still metadata-only

Result:
- [config_metadata_annotations.dart](/home/home/personal/cwatch/lib/model/config/config_metadata_annotations.dart) now defines `ConfigGroup` and `ConfigField`
- the four primitive grouped preference models are now annotated
- [config_metadata_target.dart](/home/home/personal/cwatch/lib/model/config/config_metadata_target.dart) is the explicit first-pass generator input surface
- the repo now has a real metadata seam without adding runtime behavior

## Task 14.35: define first descriptor output shape
Status: queued

Goal:
- define the first generated or generation-ready descriptor output for the annotated config metadata target

Expected scope:
- one descriptor record shape for config groups and fields
- one registry output surface for the four primitive grouped preference models
- enough room for later optional metadata such as reload impact
- still no runtime settings UI generation

Done definition:
- the first descriptor output shape is explicit
- the output target file/module is explicit
- deferred metadata such as reload impact is explicitly parked for later
- implementation can proceed without broadening the annotation scope

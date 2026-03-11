# Config Metadata Hotspot TODO

Status: active
Purpose: track bounded cleanup batches for the current config metadata single-source-of-truth hotspot.

## Task 28.1: start the config metadata hotspot pass
Status: completed

Goal:
- treat config metadata cleanup as the next active repo hotspot after the file-operation UI checkpoint
- keep this pass focused on single-source-of-truth ownership and de-complexing, not on adding codegen

Done definition:
- there is one active config metadata TODO for the new pass
- the first bounded batch is named from the current code state

Result:
- config metadata cleanup is now the active hotspot pass
- the first bounded batch should remove dead duplicated metadata ownership without changing the markdown/summary output surface

## Task 28.2: define the first bounded config metadata batch
Status: completed

Goal:
- choose one concrete config metadata cleanup slice with strong single-source-of-truth value and low behavior risk
- keep the first batch on dead annotation-layer removal rather than broader metadata redesign

Done definition:
- one first batch is explicit
- the stop condition reflects the current duplicated metadata shape

Result:
- the first bounded config metadata batch is now:
  - remove unused annotation metadata and make descriptor/registry the only active metadata source
- target files:
  - [config_metadata_annotations.dart](/home/home/personal/cwatch/lib/model/config/config_metadata_annotations.dart)
  - [config_metadata_descriptor.dart](/home/home/personal/cwatch/lib/model/config/config_metadata_descriptor.dart)
  - [config_metadata_registry.dart](/home/home/personal/cwatch/lib/model/config/config_metadata_registry.dart)
  - the primitive preference models that currently carry unused metadata annotations
- stop condition:
  - model files no longer carry duplicated `@ConfigGroup` and `@ConfigField` annotations
  - the descriptor/registry layer remains the single active metadata source
  - markdown/summary/registry tests still pass

Why this is the right first cut:
- the annotations are not used as a runtime or generated source of truth today
- the handwritten registry is the actual metadata surface used by tests and renderers
- removing the dead annotation layer de-complexes the subsystem immediately without guessing at a future codegen design

## Task 28.3: remove registry field-name duplication
Status: completed

Goal:
- reduce repeated descriptor boilerplate inside the handwritten registry
- keep the registry as the active source of truth without introducing a heavier metadata system

Done definition:
- `ConfigFieldDescriptor` can default `fieldName` from `key`
- the registry no longer repeats identical `key` and `fieldName` values across standard entries
- markdown/summary output stays unchanged

Result:
- `ConfigFieldDescriptor` now defaults `fieldName` to `key`
- the config metadata registry no longer repeats identical field-name wiring for the current preference groups
- the metadata renderers still produce the same output surface

Why this is the right next cut:
- the registry is still the right active seam, but it carried avoidable boilerplate
- this removes repetition without hiding metadata behind a new builder or generation layer

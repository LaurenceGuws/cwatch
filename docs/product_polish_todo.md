# Product Polish TODO

Status: active
Purpose: track small, visible, high-leverage consistency improvements now that the structural rewrite layers are checkpointed.

## Task 21.1: start the product polish layer
Status: completed

Goal:
- make product polish and consistency an explicit tracked layer instead of an ad hoc cleanup pass

Done definition:
- there is one high-level polish scope doc
- there is one actionable TODO doc for the layer
- the current best first hotspot is named

Result:
- the product polish layer is now explicitly tracked
- the first hotspot should be placeholder and empty-state polish

## Task 21.2: define the placeholder/empty-state polish target
Status: pending

Goal:
- identify the current canonical shared empty-state framing
- identify the most visible inconsistent adopters
- choose one narrow first implementation batch

Questions to answer:
- which surfaces already use `StandardEmptyState`
- which placeholder or unavailable surfaces still drift in wording, spacing, action placement, or icon treatment
- what should become the shared default framing without flattening feature-specific behavior

Done definition:
- one bounded placeholder/empty-state batch is chosen
- the first implementation slice is explicit

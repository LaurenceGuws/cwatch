Status: active proposal
Purpose: scoped plan for the Zide migration lane only. Not part of the main cleanup architecture baseline.

# Zide FFI Migration (0 -> Hero)

Owner: cwatch app team
Status: active
Scope: Keep production terminal/editor untouched until parity gates are met.

## Mission
Ship Zide-backed terminal/editor in cwatch only when quality exceeds current vendor-backed behavior.

## Non-Goals (for now)
- No production path replacement before parity gates pass.
- No broad architecture rewrite.
- No hidden feature flags in unrelated modules.

## Guardrails
- Experimental work lives only in `Migration` module.
- Existing server/docker/k8s/editor/terminal tabs remain vendor-backed.
- Every FFI alloc/free pair must have explicit ownership notes.
- All major changes require `flutter analyze` + targeted tests green.

## Current Baseline (done)
- Terminal/editor FFI bridges exist.
- Migration sidebar module exists.
- Smoke actions exist (full/terminal/editor).
- Prototype widgets exist in Migration view.

## Phase Plan

### Phase 0 - Hardening the Lab
Goal: Make migration lane deterministic and repeatable.
Tasks:
- Add scenario runner (`Run regression pack`) with pass/fail table.
- Add timing metrics (poll duration, snapshot size, editor op latency).
- Add explicit error categories (load, ABI, runtime, ownership).
Exit criteria:
- One-click regression pack runs in app and reports stable results.
- Failures are attributable to a clear category.

### Phase 1 - Terminal Widget Foundation
Goal: Build terminal rendering confidence.
Tasks:
- Replace text dump with cell-grid painter (`CustomPainter`).
- Render per-cell fg/bg, cursor, damage-region-aware repaints.
- Add resize handling from widget constraints.
- Add fixture-based visual checks (known VT inputs -> expected grid summary).
Exit criteria:
- Correct rendering for baseline fixtures (ASCII, colors, cursor, wide chars).
- No UI stalls during burst updates.

### Phase 2 - Terminal Interaction
Goal: Reach interactive terminal parity in lab.
Tasks:
- Keyboard input path (`send_bytes`/`send_key`).
- Clipboard paste/send text.
- Optional mouse event path.
- PTY-backed session mode in lab (`start`, `poll`, lifecycle).
Exit criteria:
- Interactive shell works in Migration terminal panel.
- Basic workflows (ls/cd/vim/top exit) are stable.

### Phase 3 - Editor Widget Foundation
Goal: Move from control buttons to usable editing surface.
Tasks:
- Editable text surface bound to FFI operations.
- Caret rendering + selection primitives.
- Undo/redo wiring to FFI actions.
- Search query/match display and next/prev navigation.
Exit criteria:
- Deterministic text operation suite passes in-app.
- Undo/redo/search behave consistently over repeated runs.

### Phase 4 - Editor UX Parity in Lab
Goal: Usable day-to-day editor in migration lane.
Tasks:
- Keyboard shortcuts mapping (undo/redo/find/replace).
- Large-file behavior checks and throttling.
- Syntax/highlight strategy decision for FFI editor surface.
Exit criteria:
- Lab editor handles common real files with acceptable responsiveness.

### Phase 5 - Side-by-Side Benchmarking
Goal: Prove better-than-vendor signal before promotion.
Tasks:
- A/B benchmark harness (vendor vs zide in lab metrics).
- Stability soak (long session, repeated open/edit/save/resize).
- Issue burn-down list prioritized by user-facing severity.
Exit criteria:
- Measured wins in target areas (stability, latency, correctness).
- No P0/P1 regressions open.

### Phase 6 - Controlled Rollout
Goal: Introduce into production behind explicit opt-in.
Tasks:
- Add production feature flag (off by default).
- Route one flow at a time (first terminal OR editor, not both).
- Collect telemetry/logs from early users.
Exit criteria:
- Flag-on users report parity or better.
- Rollback path verified.

### Phase 7 - Default Transition
Goal: Make Zide default once proven.
Tasks:
- Flip default for selected flow.
- Keep vendor backend as fallback until confidence window closes.
- Remove dead experimental scaffolding when safe.
Exit criteria:
- Confidence window complete with no severe regressions.
- Cleanup PR merged.

## Quality Gates (must pass before production routing)
- Correctness:
  - Regression pack green.
  - Golden fixture checks green.
- Stability:
  - No crashes in 60-minute soak.
  - No leak growth across repeated create/destroy cycles.
- Performance:
  - UI thread remains responsive during stress cases.
  - Latency budgets tracked and within agreed threshold.

## Risks to Track Continuously
- Threading/event-loop ownership between Flutter isolate and native runtime.
- Snapshot/event/string buffer lifetimes.
- UTF-8/wide-char rendering edge cases.
- Shortcut/key mapping divergence from expected platform behavior.

## Immediate Next 3 Tasks
1. Add `Run regression pack` with deterministic pass/fail output in Migration view.
2. Replace terminal text dump with first cell painter (fg/bg/cursor).
3. Add editor operation script runner (insert/replace/delete/undo/redo/search assertions).

## Agentic Footnote (Parallel Zide Worker Workflow)
- If a migration task needs edits in `/home/home/personal/zide` (headers, zig runtime, FFI behavior, logging), spawn a parallel worker agent dedicated to Zide.
- Worker scope must be narrow: implement only the specific Zide-side change, run the smallest relevant Zig validation, and report changed files + commands/results.
- Keep cwatch agent focused on host-side wiring/tests while Zide worker runs; merge outcomes only after verifying touched files.
- Do not mix broad refactors across both repos in one pass; keep changes incremental and reviewable.

Status: active reference
Purpose: renderer alignment guidance for the Zide migration lane only. Not a general app architecture document.

# Zide Renderer Alignment (cwatch migration)

Purpose: keep cwatch migration terminal/editor rendering aligned with Zide's renderer architecture and reference repos, instead of drifting into local-only decisions.

## Source-of-truth references (Zide)
- `/home/home/personal/zide/docs/AGENT_HOVER.md`
- `/home/home/personal/zide/docs/AGENT_HANDOFF.md`
- `/home/home/personal/zide/app_architecture/ui/font_rendering_architecture.md`
- `/home/home/personal/zide/app_architecture/ui/renderer_todo.yaml`
- `/home/home/personal/zide/app_architecture/ui/sdl3_migration_todo.yaml`
- `/home/home/personal/zide/app_architecture/ui/terminal_special_glyph_coverage.md`
- `/home/home/personal/zide/src/ui/glyph_cache.zig`

## Non-negotiable alignment constraints
- Do not optimize painter paths in cwatch that contradict Zide's text pipeline direction.
- Treat Zide SDL3 renderer decisions as baseline policy for:
  - glyph cache strategy
  - special glyph handling
  - combining/cluster shaping behavior
  - cursor/cell geometry ownership
- Any cwatch migration rendering shortcut must be explicitly marked as temporary and mapped to a Zide target state.

## Current cwatch state (migration canvas)
- Flutter `CustomPainter` path with per-frame glyph cache for terminal.
- Overlay scrollbars for terminal/editor.
- Frame-coalesced wheel/selection input path.
- No final parity yet for:
  - combining cluster shaping parity
  - special glyph/powerline parity
  - linear text pipeline parity

## Required workflow before renderer changes
1. Pick a specific Zide renderer task/doc section.
2. Write a short "alignment intent" in PR/commit notes:
   - reference file(s)
   - expected behavior
   - temporary deviation (if any)
3. Implement only the minimum cwatch migration change needed.
4. Validate with:
   - visual check in migration terminal/editor
   - `flutter analyze`
   - targeted migration tests
5. Update this file's "Current cwatch state" if architectural behavior changed.

## Next aligned chunk candidates
1. Row-run rendering in Flutter painter (align with shaped run batching intent).
2. Special glyph coverage pass using Zide coverage doc as acceptance list.
3. Combining/cluster rendering parity checks against Zide behavior snapshots.


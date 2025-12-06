# Tab Factory Guidelines

Use these conventions when adding new tab types or factories so workspace persistence and chip behavior stay consistent across Docker and Servers.

## Workspace state
- Persist `TabState` with id, kind, title/label, and any host/context identifiers the tab needs to rebuild.
- Store extra metadata (e.g., containerId) in `extra` as strings; access via `stringExtra` in `TabStateExtras`.
- Placeholder tabs should persist a stable id, a `kind` of `placeholder`, and set `canDrag`/`canRename` to false.

## Options controllers
- Provide a `TabOptionsController` for tabs with static options.
- Use `CompositeTabOptionsController` when the body manages multiple option sources (e.g., explorer + terminal options).
- Pass the controller into the body so it can push options without leaking widget state.

## Rename and close behavior
- Only allow rename (`canRename`) when the tab represents user content (dashboards, terminals, explorers). Keep placeholders non-renamable.
- For long-running sessions (e.g., terminals/commands), provide a `TabCloseWarning` in the view layer before closing.

## Wiring in factories
- Have factories set the `workspaceState` (or ensure the controller can derive `TabState` from the tab/body) so persistence stays accurate.
- Include `onCloseTab`/`onOpenTab` hooks where child tabs are created, and ensure options controllers are disposed when tabs close.

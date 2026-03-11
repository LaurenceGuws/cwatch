# StructuredDataTable Hotspot TODO

Status: active
Purpose: track the next bounded cleanup batches for the highest-risk remaining shared framework surface.

## Task 23.1: start the StructuredDataTable hotspot pass
Status: completed

Goal:
- treat `StructuredDataTable` as the next active hotspot after the current Docker pass
- keep this pass narrowly focused on what still smells now, not on general table redesign

Done definition:
- there is one StructuredDataTable-only TODO for the new pass
- the first bounded batch is named next

## Task 23.2: define the first bounded StructuredDataTable batch
Status: completed

Goal:
- choose one concrete StructuredDataTable cleanup slice with strong value and low ambiguity

Done definition:
- one first batch is explicit
- the batch has a clear stop condition
- later StructuredDataTable concerns remain queued instead of over-planned

Result:
- the first bounded StructuredDataTable batch is now:
  - sort/filter/visible-column projection split
- target files:
  - [structured_data_table_columns.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_columns.dart)
  - new projection helper under the StructuredDataTable library
- stop condition:
  - visible-column filtering, search projection, sort projection, and nullable comparison no longer live inline in the columns mixin
  - rendering, selection, keyboard, and context-menu behavior stay untouched in this batch

Why this is the right first cut:
- it isolates pure shared table-engine logic first
- it gives direct regression coverage without widget harness overhead
- it reduces risk in the most reused shared framework surface without reopening rendering behavior yet

## Task 23.3: implement the sort/filter/visible-column projection split
Status: completed

Goal:
- extract pure row/column projection logic into a dedicated StructuredDataTable helper

Done definition:
- one helper owns visible-column filtering, row search matching, sorted visible-row projection, and nullable comparison
- `_StructuredDataTableColumns` no longer owns those pure projection helpers inline
- focused regression coverage exists for the new helper

## Task 23.4: standardize row selection, right-click, and hover behavior
Status: completed

Goal:
- fix the shared interaction policy drift across table-backed list surfaces
- make right-click selection, deselection, and hover treatment behave consistently in the shared table engine instead of feature code

Done definition:
- right-click on an unselected row selects that row before opening the row context menu
- primary click on blank table space clears shared row selection consistently
- shared non-cell row hover treatment uses the same bordered hover language as the breadcrumb-inspired list standard
- focused regression coverage exists for the new selection policy

Result:
- right-click row selection now happens in:
  - [structured_data_table_context_menu.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_context_menu.dart)
- blank-area deselection and row hover framing now live in:
  - [structured_data_table_rendering.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_rendering.dart)
- shared list hover tokens now expose border treatment through:
  - [app_theme.dart](/home/home/personal/cwatch/lib/model/shared/theme/app_theme.dart)
- shared list item hover framing now uses the same direction in:
  - [selectable_list_item.dart](/home/home/personal/cwatch/lib/view/shared/widgets/lists/selectable_list_item.dart)
- focused regression coverage exists in:
  - [structured_data_table_interaction_test.dart](/home/home/personal/cwatch/test/view/shared/widgets/data_table/structured_data_table_interaction_test.dart)

Follow-up results from the same interaction-policy pass:
- the same right-click-implies-selection rule now also applies on high-traffic non-table surfaces:
  - [docker_overview.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_overview.dart)
  - [process_tree_view.dart](/home/home/personal/cwatch/lib/view/features/servers/widgets/resources/process_tree_view.dart)
  - [tab_chip.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/tab_chip.dart)
- deselection is now improved on feature-local blank surfaces where a local selection model exists:
  - Docker grouped-list tabs
  - process tree blank background
- the breadcrumb-style bordered hover language is now carried into shared and shell-facing surfaces beyond the table engine:
  - [selectable_list_item.dart](/home/home/personal/cwatch/lib/view/shared/widgets/lists/selectable_list_item.dart)
  - [navigation_button.dart](/home/home/personal/cwatch/lib/view/core/navigation/widgets/navigation_button.dart)
  - [sidebar_menu_button.dart](/home/home/personal/cwatch/lib/view/core/navigation/widgets/sidebar_menu_button.dart)
  - [window_controls.dart](/home/home/personal/cwatch/lib/view/core/navigation/widgets/window_controls.dart)

Checkpoint:
- the highest-traffic selection/right-click/hover inconsistency is now materially reduced
- remaining drift is likely limited to lower-value custom local surfaces rather than the main shared app language

## Task 23.5: extract cell-navigation engine rules from the keyboard mixin
Status: completed

Goal:
- reduce remaining shared engine complexity in the keyboard mixin without redesigning the table keyboard model
- move pure "where focus/selection should move next" rules into a dedicated helper

Done definition:
- cell-value detection no longer lives inline in the keyboard mixin
- row/column jump logic no longer lives inline in the keyboard mixin
- tab wrap/clamp coordinate calculation no longer lives inline in the keyboard mixin
- focused regression coverage exists for the helper

Result:
- pure cell-navigation logic now lives in:
  - [structured_data_table_cell_navigation.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_cell_navigation.dart)
- the keyboard mixin now delegates movement/projection decisions instead of owning those rules inline:
  - [structured_data_table_keyboard.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_keyboard.dart)
- focused regression coverage exists in:
  - [structured_data_table_cell_navigation_test.dart](/home/home/personal/cwatch/test/view/shared/widgets/data_table/structured_data_table_cell_navigation_test.dart)

## Task 23.6: extract pure cell-selection state rules from the selection mixin
Status: completed

Goal:
- reduce remaining shared engine complexity in the selection mixin without redesigning the table selection model
- move pure cell-coordinate/range state shaping into a dedicated helper

Done definition:
- coordinate clamping no longer lives inline in the selection mixin
- pure range/anchor/extent state shaping no longer lives inline in the selection mixin
- range membership checks no longer live inline in the selection mixin
- focused regression coverage exists for the helper

Result:
- pure cell-selection state logic now lives in:
  - [structured_data_table_cell_selection_state.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_cell_selection_state.dart)
- the selection mixin now delegates coordinate/range state shaping:
  - [structured_data_table_selection.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_selection.dart)
- focused regression coverage exists in:
  - [structured_data_table_cell_selection_state_test.dart](/home/home/personal/cwatch/test/view/shared/widgets/data_table/structured_data_table_cell_selection_state_test.dart)

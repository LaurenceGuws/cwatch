// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableContextMenu<T> on _StructuredDataTableStateBase<T> {
  List<StructuredDataMenuAction<T>> _contextActionsFor(
    T row,
    List<T> selectedRows,
    Offset? anchor,
  ) {
    final customBuilder = widget.rowContextMenuBuilder;
    if (customBuilder != null) {
      return customBuilder(row, selectedRows, anchor);
    }
    if (widget.rowActions.isEmpty) return const [];
    return widget.rowActions
        .map(
          (action) => StructuredDataMenuAction<T>(
            label: action.label,
            icon: action.icon,
            enabled: action.enabled,
            destructive: action.destructive,
            onSelected: (_, primary) => action.onSelected(primary),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _showContextMenu(
    T row,
    Offset position,
    List<T> selectedRows,
  ) async {
    final actions = _contextActionsFor(row, selectedRows, position);
    if (actions.isEmpty) return;
    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlay = overlayState.context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return;
    }
    final base = overlay.localToGlobal(Offset.zero);
    final anchor = position;
    final left = anchor.dx - base.dx;
    final top = anchor.dy - base.dy;
    final selected = await showMenu<StructuredDataMenuAction<T>>(
      context: context,
      useRootNavigator: true,
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlay.size.width - left,
        overlay.size.height - top,
      ),
      items: actions
          .map(
            (action) => PopupMenuItem<StructuredDataMenuAction<T>>(
              value: action,
              enabled: action.enabled,
              child: Row(
                children: [
                  Icon(
                    action.icon,
                    color: action.destructive
                        ? Theme.of(context).colorScheme.error
                        : null,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(action.label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
    selected?.onSelected(selectedRows, row);
  }

  void _showContextMenuForIndex(int index, Offset position) {
    if (_visibleRows.isEmpty) return;
    if (widget.rowActions.isEmpty &&
        widget.rowContextMenuBuilder == null &&
        widget.onRowContextMenu == null) {
      return;
    }
    if (!widget.cellSelectionEnabled && widget.rowSelectionEnabled) {
      final usesExternalSelection =
          widget.rowSelectionPredicate != null ||
          widget.selectedRowsBuilder != null;
      if (!usesExternalSelection) {
        final isAlreadySelected = _listController.selectedIndices.contains(
          index,
        );
        if (!isAlreadySelected) {
          _selectSingle(index);
        }
      }
    }
    final onRowContextMenu = widget.onRowContextMenu;
    if (onRowContextMenu != null) {
      onRowContextMenu(_visibleRows[index], position);
      return;
    }
    final selectedRows = _selectedRows();
    _showContextMenu(_visibleRows[index], position, selectedRows);
  }
}

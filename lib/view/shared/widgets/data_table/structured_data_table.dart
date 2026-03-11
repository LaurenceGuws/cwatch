import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';

import 'package:cwatch/model/shared/theme/app_theme.dart';
import '../lists/selectable_list_controller.dart';

part 'structured_data_table_constants.dart';
part 'structured_data_table_types.dart';
part 'structured_data_table_state.dart';
part 'structured_data_table_columns.dart';
part 'structured_data_table_projection.dart';
part 'structured_data_table_cell_navigation.dart';
part 'structured_data_table_cell_selection_state.dart';
part 'structured_data_table_selection.dart';
part 'structured_data_table_hit_testing.dart';
part 'structured_data_table_scrolling.dart';
part 'structured_data_table_keyboard.dart';
part 'structured_data_table_context_menu.dart';
part 'structured_data_table_rendering.dart';
part 'structured_data_table_header_resize.dart';

/// A flexible, list-backed data table with keyboard navigation, selection, and
/// contextual actions. Designed for complex lists like servers, clusters, and
/// explorer entries that need rich metadata and right-click menus.
class StructuredDataTable<T> extends StatefulWidget {
  StructuredDataTable({
    super.key,
    required this.rows,
    required this.columns,
    this.hiddenColumnIds = const {},
    this.columnIdBuilder,
    this.verticalController,
    this.horizontalController,
    this.onRowTap,
    this.onRowDoubleTap,
    this.onRowContextMenu,
    this.onRowPointerDown,
    this.onRowPointerMove,
    this.onRowPointerUp,
    this.onRowPointerCancel,
    this.onRowPointerEnter,
    this.onBackgroundContextMenu,
    this.rowSelectionEnabled = true,
    this.rowSelectionPredicate,
    this.selectedRowsBuilder,
    this.enableKeyboardNavigation = true,
    this.focusNode,
    this.onKeyEvent,
    this.onSelectionChanged,
    this.onSortChanged,
    this.onColumnsReordered,
    this.rowActions = const [],
    this.rowContextMenuBuilder,
    this.metadataBuilder,
    this.emptyState,
    this.searchQuery = '',
    this.rowSearchTextBuilder,
    this.useZebraStripes = true,
    this.surfaceBackgroundColor,
    this.refreshListenable,
    this.allowMultiSelect = true,

    this.rowHeight = 60,
    this.headerHeight,
    this.autoRowHeight = false,
    this.shrinkToContent = false,
    this.primaryDoubleClickOpensContextMenu = true,
    this.verticalScrollbarBottomInset = 0,
    this.cellSelectionEnabled = false,
    this.onCellTap,
    this.onCellEditRequested,
    this.onCellEditCommitted,
    this.onCellEditCanceled,
    this.onFillHandleCopy,
    this.rowDragPayloadBuilder,
    this.rowDragFeedbackBuilder,
    this.fitColumnsToWidth = false,
  }) : assert(columns.isNotEmpty, 'At least one column is required'),
       assert(
         !autoRowHeight ||
             (!cellSelectionEnabled &&
                 !rowSelectionEnabled &&
                 !enableKeyboardNavigation),
         'autoRowHeight requires selection and keyboard navigation to be off.',
       );

  final List<T> rows;
  final List<StructuredDataColumn<T>> columns;
  final Set<String> hiddenColumnIds;
  final String Function(StructuredDataColumn<T> column)? columnIdBuilder;
  final ScrollController? verticalController;
  final ScrollController? horizontalController;
  final ValueChanged<T>? onRowTap;
  final ValueChanged<T>? onRowDoubleTap;
  final void Function(T row, List<T> selectedRows, Offset? anchor)? onRowContextMenu;
  final void Function(int index, T row, PointerDownEvent event)?
  onRowPointerDown;
  final void Function(int index, T row, PointerMoveEvent event)?
  onRowPointerMove;
  final void Function(int index, T row, PointerUpEvent event)? onRowPointerUp;
  final void Function(int index, T row, PointerCancelEvent event)?
  onRowPointerCancel;
  final void Function(int index, T row, PointerEnterEvent event)?
  onRowPointerEnter;
  final ValueChanged<Offset>? onBackgroundContextMenu;
  final bool rowSelectionEnabled;
  final bool Function(T row)? rowSelectionPredicate;
  final List<T> Function(List<T> rows)? selectedRowsBuilder;
  final bool enableKeyboardNavigation;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  final ValueChanged<List<T>>? onSelectionChanged;
  final void Function(int columnIndex, bool ascending)? onSortChanged;
  final ValueChanged<List<StructuredDataColumn<T>>>? onColumnsReordered;
  final List<StructuredDataAction<T>> rowActions;
  final List<StructuredDataMenuAction<T>> Function(
    T row,
    List<T> selectedRows,
    Offset? anchor,
  )?
  rowContextMenuBuilder;
  final List<StructuredDataChip> Function(T row)? metadataBuilder;
  final Widget? emptyState;
  final String searchQuery;
  final String Function(T row)? rowSearchTextBuilder;
  final bool useZebraStripes;
  final Color? surfaceBackgroundColor;
  final Listenable? refreshListenable;
  final bool allowMultiSelect;
  final double rowHeight;
  final double? headerHeight;
  final bool autoRowHeight;
  final bool shrinkToContent;
  final bool primaryDoubleClickOpensContextMenu;
  final double verticalScrollbarBottomInset;
  final bool cellSelectionEnabled;
  final ValueChanged<StructuredDataCellCoordinate>? onCellTap;
  final ValueChanged<StructuredDataCellCoordinate>? onCellEditRequested;
  final ValueChanged<StructuredDataCellCoordinate>? onCellEditCommitted;
  final ValueChanged<StructuredDataCellCoordinate>? onCellEditCanceled;
  final void Function(
    StructuredDataCellRange sourceRange,
    StructuredDataCellRange targetRange,
  )?
  onFillHandleCopy;
  final Object Function(T row, List<T> selectedRows)? rowDragPayloadBuilder;
  final Widget Function(BuildContext context, T row, List<T> selectedRows)?
  rowDragFeedbackBuilder;
  final bool fitColumnsToWidth;

  @override
  State<StructuredDataTable<T>> createState() => _StructuredDataTableState<T>();
}

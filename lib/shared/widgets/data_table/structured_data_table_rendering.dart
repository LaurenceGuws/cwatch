// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableRendering<T> on _StructuredDataTableStateBase<T> {
  List<Widget> _buildRowCells(
    BuildContext context, {
    T? row,
    required bool header,
    required List<double> columnWidths,
    int? rowIndex,
  }) {
    assert(header || row != null, 'Row is required when rendering cells');
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final cells = <Widget>[];
    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final content = header
          ? Text(
              column.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              softWrap: false,
              overflow: TextOverflow.clip,
            )
          : DefaultTextStyle.merge(
              softWrap: column.wrap,
              maxLines: column.wrap ? null : 1,
              overflow: column.wrap
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              child: column.cellBuilder(context, row as T),
            );
      final cellPaddingX = widget.cellSelectionEnabled
          ? spacing.base * 1.2
          : spacing.base * 0.6;
      final aligned = Align(
        alignment: column.alignment,
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: cellPaddingX),
          child: content,
        ),
      );
      final roundedCorner = BorderRadius.zero;
      final isBodyCell = !header && rowIndex != null;
      final isSelectedCell =
          isBodyCell &&
          widget.cellSelectionEnabled &&
          _selectedCell != null &&
          _selectedCell!.rowIndex == rowIndex &&
          _selectedCell!.columnIndex == i;
      final isFocusedCell =
          isBodyCell &&
          widget.cellSelectionEnabled &&
          _focusedCell != null &&
          _focusedCell!.rowIndex == rowIndex &&
          _focusedCell!.columnIndex == i;
      final isRangeCell =
          isBodyCell &&
          widget.cellSelectionEnabled &&
          _isCellSelected(rowIndex, i);
      final isHoveredCell = isBodyCell && _isHoveredCell(rowIndex, i);
      final isHoveredColumn =
          widget.cellSelectionEnabled &&
          _hoveredCell != null &&
          _hoveredCell!.columnIndex == i;
      final separatorSide = BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        width: 0.5,
      );
      final defaultCellBorder = widget.cellSelectionEnabled
          ? Border(
              right: i == _columns.length - 1 ? BorderSide.none : separatorSide,
            )
          : null;
      final highlightColor = scheme.primary.withValues(alpha: 0.85);
      final rangeFill = scheme.primary.withValues(alpha: 0.14);
      final selectedCellBorder = Border.all(color: highlightColor, width: 1.4);
      final focusedCellBorder = Border.all(
        color: scheme.primary.withValues(alpha: 0.6),
        width: 1.1,
      );
      final hoverFill = scheme.primary.withValues(alpha: 0.08);
      final columnHoverFill = scheme.primary.withValues(alpha: 0.02);
      final cellDecoration = BoxDecoration(
        borderRadius: roundedCorner,
        color: isRangeCell
            ? rangeFill
            : (isHoveredCell
                  ? hoverFill
                  : (isHoveredColumn ? columnHoverFill : null)),
        border: widget.cellSelectionEnabled
            ? (isSelectedCell
                  ? selectedCellBorder
                  : (isFocusedCell ? focusedCellBorder : defaultCellBorder))
            : null,
      );
      final cellBody = Container(
        decoration: cellDecoration.copyWith(
          boxShadow: isSelectedCell
              ? [
                  BoxShadow(
                    color: highlightColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 0.3,
                  ),
                ]
              : null,
        ),
        child: aligned,
      );
      final cellContent = widget.autoRowHeight
          ? cellBody
          : SizedBox.expand(child: cellBody);
      final interactiveCell = isBodyCell && widget.cellSelectionEnabled
          ? Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if ((event.buttons & kPrimaryButton) != 0) {
                  final isShift = HardwareKeyboard.instance.isShiftPressed;
                  if (!isShift && _isCellSelected(rowIndex, i)) {
                    return;
                  }
                  _handleCellTap(rowIndex, i);
                }
              },
              child: MouseRegion(
                onEnter: (_) => setState(() {
                  _hoveredCell = StructuredDataCellCoordinate(
                    rowIndex: rowIndex,
                    columnIndex: i,
                  );
                }),
                onExit: (_) => setState(() {
                  final hovered = _hoveredCell;
                  if (hovered?.rowIndex == rowIndex &&
                      hovered?.columnIndex == i) {
                    _hoveredCell = null;
                  }
                }),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    final coordinate = StructuredDataCellCoordinate(
                      rowIndex: rowIndex,
                      columnIndex: i,
                    );
                    _updateCellSelection(
                      rowIndex: coordinate.rowIndex,
                      columnIndex: coordinate.columnIndex,
                    );
                    _enterCellEditMode(coordinate);
                  },
                  child: cellContent,
                ),
              ),
            )
          : cellContent;
      final cell = SizedBox(width: columnWidths[i], child: interactiveCell);
      cells.add(cell);
      if (i != _columns.length - 1) {
        final gapWidth = widget.cellSelectionEnabled ? 0.0 : spacing.base * 1.5;
        cells.add(SizedBox(width: gapWidth));
      }
    }
    return cells;
  }

  Widget _buildHeader(
    BuildContext context,
    List<double> columnWidths,
    double gapWidth,
  ) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    final headerHorizontalPadding = widget.cellSelectionEnabled
        ? spacing.base + spacing.xs
        : spacing.base * 1.2 + spacing.xs;
    final handleWidth = spacing.base * 1.5;
    final hasSpacing = gapWidth > 0;

    Widget buildResizeHandle(int index) => SizedBox(
      width: handleWidth,
      child: _HeaderResizeHandle(
        key: ValueKey('structured_data_table.resize.$index'),
        height: widget.headerHeight,
        color: scheme.outlineVariant.withValues(alpha: 0.25),
        onResize: (delta) {
          setState(() {
            final column = _columns[index];
            final current =
                _columnWidthOverrides[index] ??
                column.width ??
                columnWidths[index];
            final minWidth = max(_minColumnWidth, column.minWidth ?? 0);
            final maxWidth = _maxWidthForColumn(index);
            final target = current + delta;
            _columnWidthOverrides[index] = _clampWidth(
              target,
              minWidth,
              maxWidth,
            );
          });
        },
        onAutoFit: () => _autoFitColumn(index),
      ),
    );

    Widget wrapWithOverlay(Widget base, int index) => Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          top: 0,
          bottom: 0,
          right: -handleWidth / 2,
          width: handleWidth,
          child: buildResizeHandle(index),
        ),
      ],
    );

    return Container(
      height: widget.headerHeight,
      padding: EdgeInsets.symmetric(horizontal: headerHorizontalPadding),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Row(
        children: List<Widget>.generate(_columns.length, (index) {
          final column = _columns[index];
          final sortable = _sortValueForColumn(index) != null;
          final sorted = _sortColumnIndex == index;
          final icon = _sortAscending
              ? Icons.arrow_upward
              : Icons.arrow_downward;

          final headerLabel = Text(
            column.label,
            style: textStyle,
            softWrap: false,
            overflow: TextOverflow.clip,
          );

          final headerContent = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: headerLabel),
              if (sortable && sorted) ...[
                SizedBox(width: spacing.xs),
                Icon(icon, size: 14, color: scheme.primary),
              ],
            ],
          );

          final headerPaddingX = widget.cellSelectionEnabled
              ? spacing.base * 1.2
              : spacing.base * 0.6;
          final headerCell = Align(
            alignment: column.alignment,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: headerPaddingX,
                vertical: spacing.xs,
              ),
              child: headerContent,
            ),
          );
          final separatorSide = BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          );
          final headerCellDecorated = DecoratedBox(
            decoration: const BoxDecoration(),
            child: headerCell,
          );

          void reorderFrom(int from) {
            setState(() {
              final moved = _columns.removeAt(from);
              _columns.insert(index, moved);
              final movedWidth = _columnWidthOverrides.removeAt(from);
              _columnWidthOverrides.insert(index, movedWidth);
              _sortColumnIndex = null;
              _sortAscending = true;
              _listController.clearSelection();
            });
            widget.onColumnsReordered?.call(
              List<StructuredDataColumn<T>>.unmodifiable(_columns),
            );
          }

          final headerInteractive = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: sortable ? () => _toggleSort(index) : null,
            child: MouseRegion(
              cursor: sortable
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Row(children: [Expanded(child: headerCellDecorated)]),
            ),
          );

          final dragFeedback = Material(
            color: Colors.transparent,
            child: Container(
              width: columnWidths[index] + (hasSpacing ? 0.0 : handleWidth),
              padding: EdgeInsets.symmetric(
                horizontal: spacing.base,
                vertical: spacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.85),
                  width: 1.2,
                ),
              ),
              child: DefaultTextStyle(
                style: textStyle ?? const TextStyle(),
                child: headerContent,
              ),
            ),
          );

          final canReorder = _columns.length > 1;
          final draggableHeader = canReorder
              ? Draggable<int>(
                  data: index,
                  axis: Axis.horizontal,
                  feedback: dragFeedback,
                  child: headerInteractive,
                )
              : headerInteractive;

          final target = DragTarget<int>(
            hitTestBehavior: HitTestBehavior.deferToChild,
            onWillAcceptWithDetails: (details) => details.data != index,
            onAcceptWithDetails: (details) => reorderFrom(details.data),
            builder: (context, candidateData, rejectedData) {
              final highlight = candidateData.isNotEmpty;
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: highlight
                      ? Border(
                          bottom: BorderSide(
                            color: scheme.primary.withValues(alpha: 0.7),
                            width: 2,
                          ),
                        )
                      : null,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: index == _columns.length - 1
                          ? BorderSide.none
                          : separatorSide,
                    ),
                  ),
                  child: draggableHeader,
                ),
              );
            },
          );

          final cell = SizedBox(
            key: ValueKey('structured_data_table.header_cell.$index'),
            width: columnWidths[index],
            child: target,
          );

          if (index == _columns.length - 1) {
            return wrapWithOverlay(cell, index);
          }

          if (hasSpacing) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                cell,
                SizedBox(
                  width: gapWidth,
                  child: Transform.translate(
                    offset: Offset(-handleWidth / 2, 0),
                    child: buildResizeHandle(index),
                  ),
                ),
              ],
            );
          }

          return wrapWithOverlay(cell, index);
        }, growable: false),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index, List<double> columnWidths) {
    final row = _visibleRows[index];
    final spacing = context.appTheme.spacing;
    final listTokens = context.appTheme.list;
    final selected =
        widget.rowSelectionPredicate?.call(row) ??
        _listController.selectedIndices.contains(index);
    final focused = _listController.focusedIndex == index;
    final verticalPadding = widget.cellSelectionEnabled
        ? 0.0
        : spacing.base * 0.7;
    final gapWidth = widget.cellSelectionEnabled ? 0.0 : spacing.base * 1.5;
    final rowContentWidth =
        _tableContentWidth(columnWidths, gapWidth) +
        (widget.cellSelectionEnabled ? 0.0 : 1.0);

    final stripeBackground = widget.cellSelectionEnabled
        ? Colors.transparent
        : (widget.useZebraStripes
              ? (index.isEven
                    ? listTokens.stripeEvenBackground
                    : listTokens.stripeOddBackground)
              : Colors.transparent);
    final rowHoverBackground =
        widget.cellSelectionEnabled &&
            _hoveredCell != null &&
            _hoveredCell!.rowIndex == index
        ? listTokens.hoverBackground.withValues(alpha: 0.12)
        : Colors.transparent;
    final background = widget.cellSelectionEnabled
        ? rowHoverBackground
        : (selected ? listTokens.selectedBackground : stripeBackground);
    final overlayColor = widget.cellSelectionEnabled
        ? WidgetStateProperty.all(Colors.transparent)
        : WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return listTokens.hoverBackground;
            }
            return null;
          });

    final showFocusOutline = focused && !widget.cellSelectionEnabled;
    final border = Border.all(
      color: showFocusOutline ? listTokens.focusOutline : Colors.transparent,
      width: showFocusOutline ? 0.9 : 0.4,
    );

    Offset? tapPosition;

    final allowRowDrag =
        !widget.cellSelectionEnabled &&
        widget.rowDragPayloadBuilder != null &&
        !_isMarqueeSelecting &&
        _rowDragAnchorIndex == index;
    final rowContent = Material(
      color: background,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          widget.onRowPointerDown?.call(index, row, event);
          tapPosition = event.position;
          if ((event.buttons & kPrimaryButton) != 0) {
            if (!widget.cellSelectionEnabled) {
              final canDragRows = widget.rowDragPayloadBuilder != null;
              final isShift = HardwareKeyboard.instance.isShiftPressed;
              if (!(canDragRows &&
                  _listController.selectedIndices.contains(index) &&
                  !isShift)) {
                _handleRowTapSelection(index);
              }
            }
            widget.onRowTap?.call(row);
          }
        },
        onPointerMove: (event) =>
            widget.onRowPointerMove?.call(index, row, event),
        onPointerUp: (event) => widget.onRowPointerUp?.call(index, row, event),
        onPointerCancel: (event) =>
            widget.onRowPointerCancel?.call(index, row, event),
        child: MouseRegion(
          onEnter: widget.onRowPointerEnter == null
              ? null
              : (event) => widget.onRowPointerEnter?.call(index, row, event),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (details) {
              tapPosition = details.globalPosition;
              if (widget.cellSelectionEnabled) {
                final columnIndex = _columnIndexForLocalDx(
                  details.localPosition.dx,
                );
                if (!_isCellSelected(index, columnIndex)) {
                  _updateCellSelection(
                    rowIndex: index,
                    columnIndex: columnIndex,
                  );
                }
              }
              _showContextMenuForIndex(index, details.globalPosition);
            },
            onLongPressStart: allowRowDrag
                ? null
                : (details) {
                    tapPosition = details.globalPosition;
                    if (widget.cellSelectionEnabled) {
                      final columnIndex = _columnIndexForLocalDx(
                        details.localPosition.dx,
                      );
                      if (!_isCellSelected(index, columnIndex)) {
                        _updateCellSelection(
                          rowIndex: index,
                          columnIndex: columnIndex,
                        );
                      }
                    }
                    _showContextMenuForIndex(index, details.globalPosition);
                  },
            onDoubleTap: () {
              if (widget.primaryDoubleClickOpensContextMenu) {
                final renderBox =
                    _bodyKey.currentContext?.findRenderObject() as RenderBox?;
                final position =
                    tapPosition ??
                    renderBox?.localToGlobal(Offset.zero) ??
                    Offset.zero;
                _showContextMenuForIndex(index, position);
                return;
              }
              _handleDoubleTap(index);
            },

            child: InkWell(
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
              overlayColor: overlayColor,
              onTap: () {},
              child: Container(
                height: widget.autoRowHeight ? null : widget.rowHeight,
                constraints: widget.autoRowHeight
                    ? const BoxConstraints()
                    : BoxConstraints(minHeight: widget.rowHeight),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.cellSelectionEnabled
                      ? spacing.base
                      : spacing.base * 1.2,
                  vertical: verticalPadding,
                ),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: border,
                ),
                child: Column(
                  mainAxisSize: widget.autoRowHeight
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.autoRowHeight)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: rowContentWidth,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._buildRowCells(
                                context,
                                row: row,
                                header: false,
                                columnWidths: columnWidths,
                                rowIndex: index,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: rowContentWidth,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ..._buildRowCells(
                                  context,
                                  row: row,
                                  header: false,
                                  columnWidths: columnWidths,
                                  rowIndex: index,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!allowRowDrag) {
      return rowContent;
    }
    return LongPressDraggable<Object>(
      data: widget.rowDragPayloadBuilder!(
        row,
        _listController.selectedIndices.contains(index)
            ? _selectedRows()
            : [row],
      ),
      feedback:
          widget.rowDragFeedbackBuilder?.call(
            context,
            row,
            _listController.selectedIndices.contains(index)
                ? _selectedRows()
                : [row],
          ) ??
          Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.base,
                vertical: spacing.xs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                _listController.selectedIndices.contains(index)
                    ? _selectedRows().length > 1
                          ? '${_selectedRows().length} rows'
                          : '1 row'
                    : '1 row',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      delay: const Duration(milliseconds: 150),
      onDragStarted: () {
        if (!_listController.selectedIndices.contains(index)) {
          _selectSingle(index);
        }
      },
      onDragEnd: (_) => _setRowDragAnchor(null, null),
      onDraggableCanceled: (_, _) => _setRowDragAnchor(null, null),
      onDragCompleted: () => _setRowDragAnchor(null, null),
      child: rowContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.appTheme.section.surface;
    final surfaceBackground =
        widget.surfaceBackgroundColor ?? surface.background;

    if (_visibleRows.isEmpty && widget.emptyState != null) {
      return Container(
        decoration: BoxDecoration(
          color: surfaceBackground,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: surface.borderColor.withValues(alpha: 0.2),
            width: 0.4,
          ),
        ),

        padding: EdgeInsets.symmetric(
          horizontal: context.appTheme.spacing.base * 1.2,
          vertical: context.appTheme.spacing.base * 1.2,
        ),
        child: Center(child: widget.emptyState),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double verticalScrollbarSpace = 14;
        final availableWidth = max(
          0.0,
          constraints.maxWidth - verticalScrollbarSpace,
        );
        final spacing = context.appTheme.spacing;
        final basePadding = spacing.base;
        final headerPaddingX = widget.cellSelectionEnabled
            ? basePadding + spacing.xs
            : basePadding * 1.2 + spacing.xs;
        final rowPaddingX = widget.cellSelectionEnabled
            ? spacing.base + spacing.xs
            : spacing.base * 1.2 + spacing.xs;
        final gapWidth = widget.cellSelectionEnabled ? 0.0 : spacing.base * 1.5;
        final totalGaps = max(0, _columns.length - 1);
        final availableContentWidth = max(
          0.0,
          availableWidth -
              (2 * max(headerPaddingX, rowPaddingX)) -
              (gapWidth * totalGaps),
        );
        _lastContentWidth = availableContentWidth;
        final columnWidths = _computeColumnWidths(availableContentWidth);
        _lastColumnWidths = columnWidths;
        _lastGapWidth = gapWidth;
        _lastRowPaddingX = rowPaddingX;
        final contentWidth =
            _tableContentWidth(columnWidths, gapWidth) +
            (widget.cellSelectionEnabled ? 0.0 : 1.0);
        final paddedWidth = contentWidth + 2 * max(headerPaddingX, rowPaddingX);
        final targetWidth =
            max(constraints.maxWidth, paddedWidth + verticalScrollbarSpace) +
            1.0;

        const verticalScrollbarWidth = 10.0;
        const horizontalScrollbarThickness = 10.0;
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final body = Column(
          children: [
            _buildHeader(context, columnWidths, gapWidth),
            if (hasBoundedHeight)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: spacing.lg),
                  child: _buildBody(surface, columnWidths),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(right: spacing.lg),
                child: _buildBody(surface, columnWidths),
              ),
          ],
        );
        return Container(
          margin: surface.margin,
          decoration: BoxDecoration(
            color: surfaceBackground,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: surface.borderColor.withValues(alpha: 0.2),
              width: 0.4,
            ),
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: hasBoundedHeight ? constraints.maxHeight : null,
            child: RawScrollbar(
              controller: _verticalController,
              thumbVisibility: false,
              trackVisibility: false,
              thickness: verticalScrollbarWidth,
              radius: const Radius.circular(2),
              scrollbarOrientation: ScrollbarOrientation.right,
              padding: EdgeInsets.only(
                bottom: widget.verticalScrollbarBottomInset,
              ),
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.vertical,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: false,
                trackVisibility: false,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                thickness: horizontalScrollbarThickness,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: targetWidth,
                    height: hasBoundedHeight ? constraints.maxHeight : null,
                    child: body,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(AppSurfaceStyle surface, List<double> columnWidths) {
    final scheme = Theme.of(context).colorScheme;
    final listView = ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _verticalController,
        padding: EdgeInsets.zero,
        shrinkWrap: widget.shrinkToContent,
        primary: false,
        physics: const ClampingScrollPhysics(),
        itemExtent: widget.autoRowHeight ? null : widget.rowHeight + 1,
        cacheExtent: widget.autoRowHeight ? null : (widget.rowHeight + 1) * 20,
        itemCount: _visibleRows.length,
        itemBuilder: (context, index) => Column(
          children: [
            _buildRow(context, index, columnWidths),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );

    if (widget.cellSelectionEnabled) {
      return Focus(
        focusNode: _focusNode,
        onFocusChange: (_) => _listController.setItemCount(_visibleRows.length),
        onKeyEvent: _handleCellKeyEvent,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.touch) {
              _touchDragPointer = event.pointer;
              _isTouchDragging = true;
              _beginMarqueeSelection(event.localPosition);
              return;
            }
            if (event.kind != PointerDeviceKind.mouse) return;
            if ((event.buttons & kPrimaryButton) == 0) return;
            _marqueePointer = event.pointer;
            _setMarqueeSelecting(true);
            _beginMarqueeSelection(event.localPosition);
          },
          onPointerMove: (event) {
            if (_isTouchDragging && _touchDragPointer == event.pointer) {
              _updateMarqueeSelection(event.localPosition);
              _applyEdgeScroll(event.localPosition);
              return;
            }
            if (!_isMarqueeSelecting || _marqueePointer != event.pointer) {
              return;
            }
            _updateMarqueeSelection(event.localPosition);
          },
          onPointerUp: (event) {
            if (_touchDragPointer == event.pointer) {
              _touchDragPointer = null;
              _isTouchDragging = false;
            }
            if (_marqueePointer == event.pointer) {
              _marqueePointer = null;
              _setMarqueeSelecting(false);
            }
          },
          onPointerCancel: (event) {
            if (_touchDragPointer == event.pointer) {
              _touchDragPointer = null;
              _isTouchDragging = false;
            }
            if (_marqueePointer == event.pointer) {
              _marqueePointer = null;
              _setMarqueeSelecting(false);
            }
          },
          child: Container(key: _bodyKey, child: listView),
        ),
      );
    }

    final listContent = widget.onBackgroundContextMenu == null
        ? listView
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapDown: (details) {
              final rowIndex = _rowIndexForOffset(details.localPosition);
              if (rowIndex != null) {
                return;
              }
              widget.onBackgroundContextMenu?.call(details.globalPosition);
            },
            child: listView,
          );
    final focusNode = widget.focusNode ?? _focusNode;
    final keyboardWrapped = widget.enableKeyboardNavigation
        ? SelectableListKeyboardHandler(
            controller: _listController,
            itemCount: _visibleRows.length,
            focusNode: focusNode,
            onActivate: (index) => _handleDoubleTap(index),
            child: listContent,
          )
        : Focus(
            focusNode: focusNode,
            onKeyEvent: widget.onKeyEvent,
            child: listContent,
          );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (!widget.rowSelectionEnabled) return;
        if (event.kind != PointerDeviceKind.mouse) return;
        if ((event.buttons & kPrimaryButton) == 0) return;
        final rowIndex = _rowIndexForOffset(event.localPosition);
        if (rowIndex == null) return;
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        final hasSelection = _listController.selectedIndices.isNotEmpty;
        final isSelected = _listController.selectedIndices.contains(rowIndex);
        if (hasSelection && isSelected && !isShift) {
          _setRowDragAnchor(rowIndex, event.pointer);
          return;
        }
        _setRowDragAnchor(null, null);
        _marqueePointer = event.pointer;
        _setMarqueeSelecting(true);
        if (isShift) {
          _listController.extendSelection(rowIndex);
        } else {
          _handleRowTapSelection(rowIndex);
        }
      },
      onPointerMove: (event) {
        if (!widget.rowSelectionEnabled) return;
        if (!_isMarqueeSelecting || _marqueePointer != event.pointer) return;
        final rowIndex = _rowIndexForOffset(event.localPosition);
        if (rowIndex == null) return;
        _listController.extendSelection(rowIndex);
      },
      onPointerUp: (event) {
        if (_marqueePointer == event.pointer) {
          _marqueePointer = null;
          _setMarqueeSelecting(false);
        }
        if (_rowDragPointer == event.pointer) {
          _setRowDragAnchor(null, null);
        }
      },
      onPointerCancel: (event) {
        if (_marqueePointer == event.pointer) {
          _marqueePointer = null;
          _setMarqueeSelecting(false);
        }
        if (_rowDragPointer == event.pointer) {
          _setRowDragAnchor(null, null);
        }
      },
      child: keyboardWrapped,
    );
  }

}

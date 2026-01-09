// ignore_for_file: annotate_overrides, unused_element, unused_element_parameter
part of 'structured_data_table.dart';

abstract class _StructuredDataTableStateBase<T>
    extends State<StructuredDataTable<T>> {
  late SelectableListController _listController;
  late FocusNode _focusNode;
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;
  late final bool _ownsVerticalController;
  late final bool _ownsHorizontalController;
  late List<StructuredDataColumn<T>> _columns;
  late List<double?> _columnWidthOverrides;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final Map<int, double> _autoFitCache = {};
  StructuredDataCellCoordinate? _selectedCell;
  StructuredDataCellCoordinate? _focusedCell;
  StructuredDataCellCoordinate? _cellSelectionAnchor;
  StructuredDataCellCoordinate? _cellSelectionExtent;
  final Set<StructuredDataCellCoordinate> _additionalSelectedCells = {};
  bool _cellEditMode = false;
  int? _marqueePointer;
  bool _isMarqueeSelecting = false;
  int? _rowDragAnchorIndex;
  int? _rowDragPointer;
  StructuredDataCellCoordinate? _hoveredCell;
  final GlobalKey _bodyKey = GlobalKey();
  int? _touchDragPointer;
  bool _isTouchDragging = false;
  List<double> _lastColumnWidths = const [];
  double _lastGapWidth = 0;
  double _lastRowPaddingX = 0;
  int? _pendingScrollToRow;
  bool _scrollToRowScheduled = false;
  int? _pendingScrollToColumn;
  bool _scrollToColumnScheduled = false;
  double _lastContentWidth = 0.0;

  List<T> get _visibleRows;
  List<T> _applySearch(List<T> rows);
  bool _rowMatchesQuery(T row, String query, String Function(T row)? builder);
  List<StructuredDataColumn<T>> _buildVisibleColumns();
  int _compareNullable(Comparable<Object?>? a, Comparable<Object?>? b);
  void _toggleSort(int index);
  Comparable<Object?>? Function(T row)? _sortValueForColumn(int index);
  void _autoFitColumn(int index);
  double _tableContentWidth(List<double> columnWidths, double gapWidth);
  double _minWidthForColumn(int index, {required bool respectOverride});
  double _clampWidth(double target, double minWidth, double maxWidth);
  double _maxWidthForColumn(int index);
  double get _minColumnWidth;
  void _handleExternalRefresh();
  bool _sameColumns(
    List<StructuredDataColumn<T>> a,
    List<StructuredDataColumn<T>> b,
  );
  List<double> _computeColumnWidths(double availableWidth);
  void _setMarqueeSelecting(bool value);
  void _setRowDragAnchor(int? rowIndex, int? pointer);
  void _handleSelectionChanged();
  List<T> _selectedRows();
  void _selectSingle(int index);
  void _handleRowTapSelection(int index);
  void _handleDoubleTap(int index);
  void _handleCellTap(int? rowIndex, int columnIndex);
  void _updateCellSelection({
    required int rowIndex,
    required int columnIndex,
    bool extend = false,
    bool notify = true,
  });
  void _ensureCellFocus();
  bool _isCellSelected(int rowIndex, int columnIndex);
  bool _isHoveredCell(int rowIndex, int columnIndex);
  void _beginMarqueeSelection(Offset localPosition);
  void _updateMarqueeSelection(Offset localPosition);
  void _updateCellFocus({required int rowIndex, required int columnIndex});
  void _enterCellEditMode(StructuredDataCellCoordinate coordinate);
  void _exitCellEditMode({required bool commit});
  void _applyEdgeScroll(Offset localPosition);
  StructuredDataCellCoordinate? _cellCoordinateForOffset(Offset localPosition);
  int _columnIndexForLocalDx(double localDx);
  int? _rowIndexForOffset(Offset localPosition);
  int _pageStep();
  void _scrollToRow(int rowIndex);
  void _scrollToColumn(int columnIndex);
  void _scheduleScrollToRow(int rowIndex);
  void _scheduleScrollToColumn(int columnIndex);
  bool _cellHasValue(int rowIndex, int columnIndex);
  int _jumpRow(int startRow, int columnIndex, int delta);
  int _jumpColumn(int rowIndex, int startColumn, int delta);
  KeyEventResult _handleCellKeyEvent(FocusNode node, KeyEvent event);
  List<StructuredDataMenuAction<T>> _contextActionsFor(
    T row,
    List<T> selectedRows,
    Offset? anchor,
  );
  Future<void> _showContextMenu(T row, Offset position, List<T> selectedRows);
  void _showContextMenuForIndex(int index, Offset position);
  List<Widget> _buildRowCells(
    BuildContext context, {
    T? row,
    required bool header,
    required List<double> columnWidths,
    int? rowIndex,
  });
  Widget _buildHeader(
    BuildContext context,
    List<double> columnWidths,
    double gapWidth,
  );
  Widget _buildRow(BuildContext context, int index, List<double> columnWidths);
  Widget build(BuildContext context);
  Widget _buildBody(AppSurfaceStyle surface, List<double> columnWidths);

  @override
  void initState() {
    super.initState();
    _columns = _buildVisibleColumns();
    _columnWidthOverrides = List<double?>.filled(
      _columns.length,
      null,
      growable: true,
    );
    _autoFitCache.clear();
    _verticalController =
        widget.verticalController ?? ScrollController(keepScrollOffset: false);
    _horizontalController =
        widget.horizontalController ??
        ScrollController(keepScrollOffset: false);
    _ownsVerticalController = widget.verticalController == null;
    _ownsHorizontalController = widget.horizontalController == null;
    _listController = SelectableListController(
      allowMultiSelect: widget.allowMultiSelect,
    )..addListener(_handleSelectionChanged);
    widget.refreshListenable?.addListener(_handleExternalRefresh);
    _focusNode = FocusNode(debugLabel: 'StructuredDataTable');
    _listController.setItemCount(_visibleRows.length);
  }

  @override
  void didUpdateWidget(covariant StructuredDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameColumns(oldWidget.columns, widget.columns) ||
        oldWidget.hiddenColumnIds != widget.hiddenColumnIds) {
      _columns = _buildVisibleColumns();
      _columnWidthOverrides = List<double?>.filled(
        _columns.length,
        null,
        growable: true,
      );
      _autoFitCache.clear();
      _sortColumnIndex = null;
      _sortAscending = true;
      _listController.clearSelection();
      _selectedCell = null;
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
    }
    if (oldWidget.allowMultiSelect != widget.allowMultiSelect) {
      _listController
        ..removeListener(_handleSelectionChanged)
        ..dispose();
      _listController = SelectableListController(
        allowMultiSelect: widget.allowMultiSelect,
      )..addListener(_handleSelectionChanged);
    }
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_handleExternalRefresh);
      widget.refreshListenable?.addListener(_handleExternalRefresh);
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      _listController.clearSelection();
      if (widget.cellSelectionEnabled) {
        _selectedCell = null;
        _focusedCell = null;
        _cellSelectionAnchor = null;
        _cellSelectionExtent = null;
        _additionalSelectedCells.clear();
        _cellEditMode = false;
      }
    }
    if (oldWidget.verticalController != widget.verticalController &&
        widget.verticalController != null) {
      if (_ownsVerticalController) {
        _verticalController.dispose();
      }
      _verticalController = widget.verticalController!;
      _ownsVerticalController = false;
    }
    if (oldWidget.horizontalController != widget.horizontalController &&
        widget.horizontalController != null) {
      if (_ownsHorizontalController) {
        _horizontalController.dispose();
      }
      _horizontalController = widget.horizontalController!;
      _ownsHorizontalController = false;
    }
    if (!widget.cellSelectionEnabled) {
      _selectedCell = null;
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
    } else if (oldWidget.cellSelectionEnabled != widget.cellSelectionEnabled) {
      _selectedCell = null;
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
      _listController.clearSelection();
    }
    if (_selectedCell != null &&
        (_selectedCell!.rowIndex >= _visibleRows.length ||
            _selectedCell!.columnIndex >= _columns.length)) {
      _selectedCell = null;
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
    }
    if (_columns.isEmpty && widget.columns.isNotEmpty) {
      _columns = _buildVisibleColumns();
      _columnWidthOverrides = List<double?>.filled(
        _columns.length,
        null,
        growable: true,
      );
      _autoFitCache.clear();
    }
    _listController.setItemCount(_visibleRows.length);
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_handleExternalRefresh);
    _listController
      ..removeListener(_handleSelectionChanged)
      ..dispose();
    _focusNode.dispose();
    if (_ownsVerticalController) {
      _verticalController.dispose();
    }
    if (_ownsHorizontalController) {
      _horizontalController.dispose();
    }
    super.dispose();
  }
}

class _StructuredDataTableState<T> extends _StructuredDataTableStateBase<T>
    with
        _StructuredDataTableColumns<T>,
        _StructuredDataTableSelection<T>,
        _StructuredDataTableHitTesting<T>,
        _StructuredDataTableScrolling<T>,
        _StructuredDataTableKeyboard<T>,
        _StructuredDataTableContextMenu<T>,
        _StructuredDataTableRendering<T> {}

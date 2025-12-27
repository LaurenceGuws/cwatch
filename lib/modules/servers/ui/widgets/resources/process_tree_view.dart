import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'resource_models.dart';

/// Controller for process tree view
class ProcessTreeController {
  VoidCallback? _expandAll;
  VoidCallback? _collapseAll;

  void _attach({
    required VoidCallback expandAll,
    required VoidCallback collapseAll,
  }) {
    _expandAll = expandAll;
    _collapseAll = collapseAll;
  }

  void _detach() {
    _expandAll = null;
    _collapseAll = null;
  }

  void expandAll() => _expandAll?.call();
  void collapseAll() => _collapseAll?.call();
}

/// Process tree view widget
class ProcessTreeView extends StatefulWidget {
  const ProcessTreeView({super.key, required this.processes, this.controller});

  final List<ProcessInfo> processes;
  final ProcessTreeController? controller;

  @override
  State<ProcessTreeView> createState() => _ProcessTreeViewState();
}

class _ProcessTreeViewState extends State<ProcessTreeView> {
  final Set<int> _collapsedPids = {};
  int? _selectedPid;
  ProcessSortColumn _sortColumn = ProcessSortColumn.cpu;
  bool _sortAscending = false;
  final FocusNode _focusNode = FocusNode();
  List<ProcessTreeRowData> _visibleRows = const [];

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(
      expandAll: _expandAll,
      collapseAll: _collapseAll,
    );
  }

  @override
  void didUpdateWidget(covariant ProcessTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(
        expandAll: _expandAll,
        collapseAll: _collapseAll,
      );
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildProcessRowData(widget.processes);
    _visibleRows = rows;
    final rowHeight = 40.0;
    final minHeight = 200.0;
    final maxHeight = 420.0;
    final height = rows.isEmpty
        ? minHeight
        : min(maxHeight, max(minHeight, rows.length * rowHeight));
    return FocusableActionDetector(
      focusNode: _focusNode,
      autofocus: false,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): MoveSelectionIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): MoveSelectionIntent(-1),
      },
      actions: {
        MoveSelectionIntent: CallbackAction<MoveSelectionIntent>(
          onInvoke: (intent) {
            _moveSelection(intent.offset);
            return null;
          },
        ),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = context.appTheme.spacing;
          final tableWidth = max<double>(
            _minProcessTableWidth,
            constraints.maxWidth,
          );
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProcessHeader(
                    tableWidth: tableWidth,
                    sortColumn: _sortColumn,
                    ascending: _sortAscending,
                    onSort: _handleSort,
                  ),
                  SizedBox(height: spacing.md),
                  Container(
                    width: tableWidth,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: SizedBox(
                      height: height,
                      child: ScrollConfiguration(
                        behavior: const ScrollBehavior().copyWith(
                          scrollbars: true,
                        ),
                        child: ListView.builder(
                          itemCount: rows.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return ProcessTreeRow(
                              row: row,
                              selected: row.info.pid == _selectedPid,
                              onTap: () {
                                _focusNode.requestFocus();
                                setState(() => _selectedPid = row.info.pid);
                              },
                              onToggleCollapse: row.isExpandable
                                  ? () => setState(() {
                                      if (_collapsedPids.contains(
                                        row.info.pid,
                                      )) {
                                        _collapsedPids.remove(row.info.pid);
                                      } else {
                                        _collapsedPids.add(row.info.pid);
                                      }
                                    })
                                  : null,
                              onContextMenu: (position) =>
                                  _showContextMenu(context, position, row.info),
                              onDoubleTap: row.isExpandable
                                  ? () {
                                      setState(() {
                                        if (_collapsedPids.contains(
                                          row.info.pid,
                                        )) {
                                          _collapsedPids.remove(row.info.pid);
                                        } else {
                                          _collapsedPids.add(row.info.pid);
                                        }
                                      });
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset position,
    ProcessInfo info,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, 0),
      items: const [
        PopupMenuItem(value: 'info', child: Text('Info')),
        PopupMenuItem(value: 'signals', child: Text('Signals')),
        PopupMenuItem(value: 'terminate', child: Text('Terminate')),
        PopupMenuItem(value: 'kill', child: Text('Kill')),
      ],
    );
    if (!context.mounted) return;
    if (selected == null) {
      return;
    }
    switch (selected) {
      case 'info':
        _showInfoDialog(context, info);
        break;
      case 'signals':
        _showSignalsDialog(context, info);
        break;
      case 'terminate':
        _showSnack(context, 'Terminate ${info.command} (${info.pid})');
        break;
      case 'kill':
        _showSnack(context, 'Kill ${info.command} (${info.pid})');
        break;
    }
  }

  void _showInfoDialog(BuildContext context, ProcessInfo info) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Process ${info.pid}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Command: ${info.command}'),
            Text('Parent PID: ${info.ppid}'),
            Text('CPU: ${info.cpu.toStringAsFixed(2)}%'),
            Text(
              'Memory: ${_formatBytes(info.memoryBytes)} '
              '(${info.memoryPercent.toStringAsFixed(2)}%)',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSignalsDialog(BuildContext context, ProcessInfo info) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send signal to ${info.pid}'),
        content: SizedBox(
          width: 280,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final signal in [
                'HUP',
                'INT',
                'TERM',
                'KILL',
                'USR1',
                'USR2',
              ])
                ListTile(
                  title: Text('SIG$signal'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showSnack(context, 'Sent SIG$signal to ${info.pid}');
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleSort(ProcessSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending =
            column == ProcessSortColumn.command ||
            column == ProcessSortColumn.pid;
      }
    });
  }

  void _moveSelection(int offset) {
    if (_visibleRows.isEmpty) {
      return;
    }
    final currentIndex = _selectedPid == null
        ? -1
        : _visibleRows.indexWhere((row) => row.info.pid == _selectedPid);
    final nextIndex = (currentIndex + offset).clamp(0, _visibleRows.length - 1);
    setState(() {
      _selectedPid = _visibleRows[nextIndex].info.pid;
    });
  }

  void _collapseAll() {
    setState(() {
      _collapsedPids
        ..clear()
        ..addAll(
          _visibleRows
              .where((row) => row.isExpandable)
              .map((row) => row.info.pid),
        );
    });
  }

  void _expandAll() {
    setState(() {
      _collapsedPids.clear();
    });
  }

  List<ProcessTreeRowData> _buildProcessRowData(List<ProcessInfo> processes) {
    if (processes.isEmpty) {
      return const [];
    }
    final nodes = {for (final info in processes) info.pid: ProcessNode(info)};
    final roots = <ProcessNode>[];
    for (final node in nodes.values) {
      final parent = nodes[node.info.ppid];
      if (parent != null && parent != node) {
        parent.children.add(node);
      } else {
        roots.add(node);
      }
    }

    double sortValueCpu(ProcessNode node) => _aggregateCpu(node);
    double sortValueMem(ProcessNode node) => _aggregateMem(node);

    void sortNodes(List<ProcessNode> list) {
      list.sort((a, b) {
        int result;
        switch (_sortColumn) {
          case ProcessSortColumn.cpu:
            result = sortValueCpu(a).compareTo(sortValueCpu(b));
            break;
          case ProcessSortColumn.memory:
            result = sortValueMem(a).compareTo(sortValueMem(b));
            break;
          case ProcessSortColumn.pid:
            result = a.info.pid.compareTo(b.info.pid);
            break;
          case ProcessSortColumn.command:
            result = a.info.command.toLowerCase().compareTo(
              b.info.command.toLowerCase(),
            );
            break;
        }
        return _sortAscending ? result : -result;
      });
      for (final node in list) {
        sortNodes(node.children);
      }
    }

    sortNodes(roots);
    final rows = <ProcessTreeRowData>[];
    ProcessTreeRowData buildRow(ProcessNode node, List<bool> ancestorFlags) {
      final totalCpu =
          node.info.cpu +
          node.children.fold(0.0, (sum, child) => sum + _aggregateCpu(child));
      final totalMem =
          node.info.memoryBytes +
          node.children.fold(0.0, (sum, child) => sum + _aggregateMem(child));
      final isCollapsed = _collapsedPids.contains(node.info.pid);
      return ProcessTreeRowData(
        info: node.info,
        ancestorLastFlags: ancestorFlags,
        isExpandable: node.children.isNotEmpty,
        isCollapsed: isCollapsed,
        totalCpu: totalCpu,
        totalMem: totalMem,
      );
    }

    void visit(ProcessNode node, List<bool> ancestorFlags) {
      rows.add(buildRow(node, ancestorFlags));
      final isCollapsed = _collapsedPids.contains(node.info.pid);
      if (isCollapsed) {
        return;
      }
      for (var i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final isLast = i == node.children.length - 1;
        visit(child, [...ancestorFlags, isLast]);
      }
    }

    for (final root in roots) {
      visit(root, const []);
    }
    return rows;
  }

  double _aggregateCpu(ProcessNode node) {
    return node.info.cpu +
        node.children.fold(0.0, (sum, child) => sum + _aggregateCpu(child));
  }

  double _aggregateMem(ProcessNode node) {
    return node.info.memoryBytes +
        node.children.fold(0.0, (sum, child) => sum + _aggregateMem(child));
  }
}

/// Process tree row widget
class ProcessTreeRow extends StatelessWidget {
  const ProcessTreeRow({
    super.key,
    required this.row,
    required this.selected,
    this.onTap,
    this.onDoubleTap,
    this.onToggleCollapse,
    this.onContextMenu,
  });

  final ProcessTreeRowData row;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onToggleCollapse;
  final ValueChanged<Offset>? onContextMenu;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;
    final prefix = _buildPrefix(row.ancestorLastFlags);
    final displayCpu = row.isCollapsed ? row.totalCpu : row.info.cpu;
    final displayMemBytes = row.isCollapsed
        ? row.totalMem
        : row.info.memoryBytes;
    final highlight = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.15)
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onToggleCollapse,
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.base,
          vertical: spacing.xs,
        ),
        decoration: BoxDecoration(
          color: highlight,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: _pidFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${row.info.pid}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
          flex: _commandFlex,
          child: Padding(
            padding: EdgeInsets.only(left: spacing.sm),
            child: Row(
              children: [
                if (row.isExpandable)
                  GestureDetector(
                        onTap: onToggleCollapse,
                        child: Icon(
                          row.isCollapsed
                              ? Icons.chevron_right
                              : Icons.expand_more,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    SizedBox(width: spacing.xl),
                if (prefix.isNotEmpty)
                  Text(
                    prefix,
                        style: textStyle?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        row.info.command,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: _cpuFlex,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  displayCpu.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            Expanded(
              flex: _memoryFlex,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatBytes(displayMemBytes),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildPrefix(List<bool> ancestorFlags) {
    if (ancestorFlags.isEmpty) {
      return '';
    }
    const branch = '│   ';
    const empty = '    ';
    const tee = '├── ';
    const last = '╰── ';
    final buffer = StringBuffer();
    for (var i = 0; i < ancestorFlags.length; i++) {
      final isLastAncestor = ancestorFlags[i];
      final isTerminal = i == ancestorFlags.length - 1;
      if (isTerminal) {
        buffer.write(isLastAncestor ? last : tee);
      } else {
        buffer.write(isLastAncestor ? empty : branch);
      }
    }
    return buffer.toString();
  }
}

/// Process header widget
class ProcessHeader extends StatelessWidget {
  const ProcessHeader({
    super.key,
    required this.tableWidth,
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
  });

  final double tableWidth;
  final ProcessSortColumn sortColumn;
  final bool ascending;
  final ValueChanged<ProcessSortColumn> onSort;

  Widget _buildHeaderCell({
    required BuildContext context,
    required String label,
    required ProcessSortColumn column,
    bool expand = false,
  }) {
    final spacing = context.appTheme.spacing;
    final isActive = sortColumn == column;
    final icon = isActive
        ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
        : null;
    final content = Row(
      mainAxisAlignment: expand
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        if (icon != null) ...[
          SizedBox(width: spacing.sm),
          Icon(icon, size: 12),
        ],
      ],
    );
    final child = InkWell(
      onTap: () => onSort(column),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.md),
        child: content,
      ),
    );
    return Expanded(
      flex: switch (column) {
        ProcessSortColumn.pid => _pidFlex,
        ProcessSortColumn.command => _commandFlex,
        ProcessSortColumn.cpu => _cpuFlex,
        ProcessSortColumn.memory => _memoryFlex,
      },
      child: Align(
        alignment: expand ? Alignment.centerLeft : Alignment.center,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tableWidth,
      child: Row(
        children: [
          _buildHeaderCell(
            context: context,
            label: 'PID',
            column: ProcessSortColumn.pid,
          ),
          _buildHeaderCell(
            context: context,
            label: 'Command',
            column: ProcessSortColumn.command,
            expand: true,
          ),
          _buildHeaderCell(
            context: context,
            label: 'CPU',
            column: ProcessSortColumn.cpu,
          ),
          _buildHeaderCell(
            context: context,
            label: 'Memory',
            column: ProcessSortColumn.memory,
          ),
        ],
      ),
    );
  }
}

/// Process node for tree structure
class ProcessNode {
  ProcessNode(this.info);

  final ProcessInfo info;
  final List<ProcessNode> children = [];
}

/// Process tree row data
class ProcessTreeRowData {
  const ProcessTreeRowData({
    required this.info,
    required this.ancestorLastFlags,
    required this.isExpandable,
    required this.isCollapsed,
    required this.totalCpu,
    required this.totalMem,
  });

  final ProcessInfo info;
  final List<bool> ancestorLastFlags;
  final bool isExpandable;
  final bool isCollapsed;
  final double totalCpu;
  final double totalMem;

  int get depth => ancestorLastFlags.length;
}

/// Process sort column enum
enum ProcessSortColumn { cpu, memory, pid, command }

const _pidFlex = 2;
const _commandFlex = 6;
const _cpuFlex = 3;
const _memoryFlex = 3;
const _minProcessTableWidth = 620.0;

/// Move selection intent
class MoveSelectionIntent extends Intent {
  const MoveSelectionIntent(this.offset);

  final int offset;
}

/// Format bytes helper
String _formatBytes(double bytes) {
  if (bytes.isNaN || bytes <= 0) {
    return '0 MB';
  }
  const double kb = 1024;
  const double mb = kb * 1024;
  const double gb = mb * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(0)} MB';
  }
  return '${(bytes / kb).toStringAsFixed(0)} KB';
}

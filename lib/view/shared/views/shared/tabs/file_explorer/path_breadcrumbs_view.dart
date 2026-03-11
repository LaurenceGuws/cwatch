import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cwatch/model/shared/services/path_utils.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';

class PathBreadcrumbsView extends StatefulWidget {
  const PathBreadcrumbsView({
    super.key,
    required this.currentPath,
    required this.pathHistory,
    required this.onPathChanged,
    this.onPrefetchPath,
    this.onShowMenu,
  });

  final String currentPath;
  final Set<String> pathHistory;
  final ValueChanged<String> onPathChanged;
  final ValueChanged<String>? onPrefetchPath;
  final Future<String?> Function(
    RelativeRect position,
    List<PopupMenuEntry<String>> items,
    BoxConstraints constraints,
  )?
  onShowMenu;

  @override
  State<PathBreadcrumbsView> createState() => _PathBreadcrumbsViewState();
}

class _PathBreadcrumbsViewState extends State<PathBreadcrumbsView> {
  final ScrollController _scrollController = ScrollController();
  String _lastPath = '';
  final Set<String> _requestedPaths = {};
  final Set<String> _resolvedPaths = {};
  final Map<String, int> _requestedCounts = {};
  final Map<String, DateTime> _requestedAt = {};

  String _normalizePath(String path) {
    final segments = path.split('/');
    final stack = <String>[];
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..') {
        if (stack.isNotEmpty) {
          stack.removeLast();
        }
      } else {
        stack.add(segment);
      }
    }
    return '/${stack.join('/')}';
  }

  @override
  void didUpdateWidget(covariant PathBreadcrumbsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _scrollToEndIfNeeded(widget.currentPath);
    }
    if (oldWidget.pathHistory != widget.pathHistory) {
      _resolveRequestedPaths();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final normalizedCurrent = PathUtils.normalizePath(widget.currentPath);
    final segments = widget.currentPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final chips = <Widget>[
      _BreadcrumbButton(
        label: '/',
        onPressed: normalizedCurrent == '/'
            ? null
            : () => widget.onPathChanged('/'),
        suffix: _buildOptionalSeparator(context, '/', widget.onPrefetchPath),
      ),
    ];

    var runningPath = '';
    for (final segment in segments) {
      runningPath += '/$segment';
      final normalizedRunningPath = _normalizePath(runningPath);
      chips.add(
        Tooltip(
          message: segment,
          waitDuration: const Duration(milliseconds: 400),
          child: _BreadcrumbButton(
            label: segment,
            onPressed: () => widget.onPathChanged(normalizedRunningPath),
            suffix: _buildOptionalSeparator(
              context,
              normalizedRunningPath,
              widget.onPrefetchPath,
            ),
          ),
        ),
      );
    }

    final spacedChips = <Widget>[];
    for (final chip in chips) {
      if (spacedChips.isNotEmpty) {
        spacedChips.add(SizedBox(width: spacing.xs));
      }
      spacedChips.add(chip);
    }

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: spacedChips,
      ),
    );
  }

  Widget? _buildOptionalSeparator(
    BuildContext context,
    String basePath,
    ValueChanged<String>? onPrefetchPath,
  ) {
    final isResolved = _isResolved(basePath);
    if (isResolved && _childDirectoriesForPath(basePath).isEmpty) {
      return null;
    }
    return _BreadcrumbMenuButton(
      basePath: basePath,
      getChildren: () => _childDirectoriesForPath(basePath),
      onPrefetchPath: onPrefetchPath,
      onPathChanged: widget.onPathChanged,
      onShowMenu: widget.onShowMenu,
      isResolved: isResolved,
      onRequested: () => _markRequested(basePath),
    );
  }

  List<String> _childDirectoriesForPath(String basePath) {
    final normalizedBase = PathUtils.normalizePath(basePath);
    final prefix = normalizedBase == '/' ? '/' : '$normalizedBase/';
    final children = <String>{};
    for (final path in widget.pathHistory) {
      final normalized = PathUtils.normalizePath(path);
      if (normalized == normalizedBase || !normalized.startsWith(prefix)) {
        continue;
      }
      final remainder = normalized.substring(prefix.length);
      if (remainder.isEmpty) {
        continue;
      }
      final child = remainder.split('/').first;
      if (child.isNotEmpty) {
        children.add(child);
      }
    }
    final sorted = children.toList()..sort();
    return sorted;
  }

  bool _isResolved(String basePath) {
    return _resolvedPaths.contains(basePath);
  }

  void _markRequested(String basePath) {
    _requestedPaths.add(basePath);
    _requestedCounts[basePath] = _childDirectoriesForPath(basePath).length;
    _requestedAt[basePath] = DateTime.now();
    _resolveRequestedPaths();
    _scheduleResolveCheck();
  }

  void _resolveRequestedPaths() {
    final resolved = <String>{};
    for (final path in _requestedPaths) {
      if (!widget.pathHistory.contains(path)) {
        continue;
      }
      final currentCount = _childDirectoriesForPath(path).length;
      final originalCount = _requestedCounts[path];
      final requestedAt = _requestedAt[path];
      final agedOut =
          requestedAt != null &&
          DateTime.now().difference(requestedAt) > const Duration(seconds: 1);
      if (originalCount == null || currentCount != originalCount || agedOut) {
        resolved.add(path);
      }
    }
    if (resolved.isEmpty) {
      return;
    }
    _resolvedPaths.addAll(resolved);
    _requestedPaths.removeAll(resolved);
    resolved.forEach(_requestedCounts.remove);
    resolved.forEach(_requestedAt.remove);
  }

  void _scheduleResolveCheck() {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }
      setState(_resolveRequestedPaths);
    });
  }

  void _scrollToEndIfNeeded(String path) {
    if (_lastPath.isEmpty || path.length > _lastPath.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      });
    }
    _lastPath = path;
  }
}

class _BreadcrumbMenuButton extends StatelessWidget {
  const _BreadcrumbMenuButton({
    required this.basePath,
    required this.getChildren,
    required this.onPrefetchPath,
    required this.onPathChanged,
    this.onShowMenu,
    required this.isResolved,
    required this.onRequested,
  });

  final String basePath;
  final List<String> Function() getChildren;
  final ValueChanged<String>? onPrefetchPath;
  final ValueChanged<String> onPathChanged;
  final Future<String?> Function(
    RelativeRect position,
    List<PopupMenuEntry<String>> items,
    BoxConstraints constraints,
  )?
  onShowMenu;
  final bool isResolved;
  final VoidCallback onRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = getChildren();
    return _BreadcrumbMenuButtonBody(
      basePath: basePath,
      children: children,
      getChildren: getChildren,
      onPrefetchPath: onPrefetchPath,
      onPathChanged: onPathChanged,
      onShowMenu: onShowMenu,
      iconColor: theme.colorScheme.outline,
      isResolved: isResolved,
      onRequested: onRequested,
    );
  }
}

class _BreadcrumbMenuButtonBody extends StatefulWidget {
  const _BreadcrumbMenuButtonBody({
    required this.basePath,
    required this.children,
    required this.getChildren,
    required this.onPrefetchPath,
    required this.onPathChanged,
    this.onShowMenu,
    required this.iconColor,
    required this.isResolved,
    required this.onRequested,
  });

  final String basePath;
  final List<String> children;
  final List<String> Function() getChildren;
  final ValueChanged<String>? onPrefetchPath;
  final ValueChanged<String> onPathChanged;
  final Future<String?> Function(
    RelativeRect position,
    List<PopupMenuEntry<String>> items,
    BoxConstraints constraints,
  )?
  onShowMenu;
  final Color iconColor;
  final bool isResolved;
  final VoidCallback onRequested;

  @override
  State<_BreadcrumbMenuButtonBody> createState() =>
      _BreadcrumbMenuButtonBodyState();
}

class _BreadcrumbMenuButtonBodyState extends State<_BreadcrumbMenuButtonBody> {
  bool _loading = false;
  bool _openWhenReady = false;
  bool _menuOpen = false;

  @override
  void didUpdateWidget(covariant _BreadcrumbMenuButtonBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_openWhenReady && (widget.children.isNotEmpty || widget.isResolved)) {
      _openWhenReady = false;
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMenu(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
      onTap: () => _handleTap(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24, minWidth: 8),
        child: Center(
          child: _loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.iconColor,
                  ),
                )
              : Icon(
                  _menuOpen ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: widget.iconColor,
                ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (!widget.isResolved) {
      widget.onPrefetchPath?.call(widget.basePath);
      widget.onRequested();
      if (!_loading) {
        setState(() {
          _loading = true;
          _openWhenReady = true;
        });
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!mounted) {
            return;
          }
          if (!widget.isResolved) {
            setState(() {
              _loading = false;
              _openWhenReady = false;
            });
          }
        });
      }
      return;
    }
    _showMenu(context);
  }

  void _showMenu(BuildContext context) {
    final children = widget.getChildren();
    if (children.isEmpty) {
      return;
    }
    if (!_menuOpen) {
      setState(() => _menuOpen = true);
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final renderBox = context.findRenderObject() as RenderBox;
    final target = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomEdge = target.dy + renderBox.size.height;
    final availableHeight = overlay.size.height - bottomEdge - 8;
    final maxHeight = math.max(120.0, availableHeight);
    final position = RelativeRect.fromLTRB(
      target.dx,
      bottomEdge + 4,
      overlay.size.width - target.dx - renderBox.size.width,
      overlay.size.height - bottomEdge,
    );
    final items = children
        .map((child) => PopupMenuItem<String>(value: child, child: Text(child)))
        .toList();
    final constraints = BoxConstraints(
      minWidth: renderBox.size.width,
      maxHeight: maxHeight,
    );
    final showMenuAction = widget.onShowMenu;
    final menuFuture = showMenuAction != null
        ? showMenuAction(position, items, constraints)
        : showMenu<String>(
            context: context,
            position: position,
            constraints: constraints,
            items: items,
          );
    menuFuture.then((value) {
      if (mounted && _menuOpen) {
        setState(() => _menuOpen = false);
      }
      if (value == null) {
        return;
      }
      widget.onPathChanged(PathUtils.joinPath(widget.basePath, value));
    });
  }
}

class _BreadcrumbButton extends StatefulWidget {
  const _BreadcrumbButton({
    required this.label,
    required this.onPressed,
    this.suffix,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? suffix;

  @override
  State<_BreadcrumbButton> createState() => _BreadcrumbButtonState();
}

class _BreadcrumbButtonState extends State<_BreadcrumbButton> {
  bool _hovered = false;
  bool _labelHover = false;
  bool _suffixHover = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final theme = Theme.of(context);
    final borderColor = _hovered
        ? theme.colorScheme.outlineVariant
        : Colors.transparent;
    final backgroundColor = _hovered
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.transparent;
    final innerHoverColor = theme.colorScheme.surfaceContainer;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MouseRegion(
                onEnter: (_) => setState(() => _labelHover = true),
                onExit: (_) => setState(() => _labelHover = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: _labelHover ? innerHoverColor : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(6),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(6),
                    ),
                    onTap: widget.onPressed,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.sm,
                        vertical: spacing.xs * 0.5,
                      ),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null)
                MouseRegion(
                  onEnter: (_) => setState(() => _suffixHover = true),
                  onExit: (_) => setState(() => _suffixHover = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: _suffixHover
                          ? innerHoverColor
                          : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(6),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.xs * 0.25,
                    ),
                    child: widget.suffix!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

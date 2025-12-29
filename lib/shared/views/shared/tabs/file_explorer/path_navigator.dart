import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/nerd_fonts.dart';
import 'path_utils.dart';

/// Widget for navigating file paths with breadcrumbs or text input
class PathNavigator extends StatefulWidget {
  const PathNavigator({
    super.key,
    required this.currentPath,
    required this.pathHistory,
    required this.onPathChanged,
    this.showBreadcrumbs = true,
    this.onShowBreadcrumbsChanged,
    this.onNavigateToSubdirectory,
    this.onPrefetchPath,
    required this.searchActive,
    required this.searchQuery,
    this.searchInProgress = false,
    this.onSearchActiveChanged,
    this.onSearchQueryChanged,
    this.onSearchSubmitted,
    this.onSearchCancelled,
    required this.searchInclude,
    required this.searchExclude,
    required this.searchMatchCase,
    required this.searchMatchWholeWord,
    required this.searchContents,
    this.onSearchIncludeChanged,
    this.onSearchExcludeChanged,
    this.onSearchMatchCaseChanged,
    this.onSearchMatchWholeWordChanged,
    this.onSearchContentsChanged,
  });

  final String currentPath;
  final Set<String> pathHistory;
  final ValueChanged<String> onPathChanged;
  final bool showBreadcrumbs;
  final ValueChanged<bool>? onShowBreadcrumbsChanged;
  final VoidCallback? onNavigateToSubdirectory;
  final ValueChanged<String>? onPrefetchPath;
  final bool searchActive;
  final String searchQuery;
  final bool searchInProgress;
  final ValueChanged<bool>? onSearchActiveChanged;
  final ValueChanged<String>? onSearchQueryChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onSearchCancelled;
  final String searchInclude;
  final String searchExclude;
  final bool searchMatchCase;
  final bool searchMatchWholeWord;
  final bool searchContents;
  final ValueChanged<String>? onSearchIncludeChanged;
  final ValueChanged<String>? onSearchExcludeChanged;
  final VoidCallback? onSearchMatchCaseChanged;
  final VoidCallback? onSearchMatchWholeWordChanged;
  final ValueChanged<bool>? onSearchContentsChanged;

  @override
  State<PathNavigator> createState() => _PathNavigatorState();
}

class _PathNavigatorState extends State<PathNavigator> {
  TextEditingController? _pathFieldController;
  bool _searchExpanded = true;

  @override
  void didUpdateWidget(PathNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      final controller = _pathFieldController;
      if (controller != null) {
        controller.value = controller.value.copyWith(
          text: widget.currentPath,
          selection: TextSelection.collapsed(
            offset: widget.currentPath.length,
          ),
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final lateController = _pathFieldController;
          if (lateController == null) {
            return;
          }
          lateController.value = lateController.value.copyWith(
            text: widget.currentPath,
            selection: TextSelection.collapsed(
              offset: widget.currentPath.length,
            ),
          );
        });
      }
    }
    if (!oldWidget.searchActive && widget.searchActive) {
      _searchExpanded = true;
    }
  }

  @override
  void dispose() {
    _pathFieldController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.appTheme.spacing;
    final toggle = ToggleButtons(
      isSelected: [widget.showBreadcrumbs, !widget.showBreadcrumbs],
      onPressed: (index) {
        widget.onShowBreadcrumbsChanged?.call(index == 0);
      },
      borderRadius: BorderRadius.circular(2),
      constraints: const BoxConstraints(minWidth: 26, minHeight: 24),
      children: const [
        Icon(Icons.alt_route, size: 14),
        Icon(Icons.text_fields, size: 14),
      ],
    );

    final content = widget.showBreadcrumbs
        ? _BreadcrumbsView(
            currentPath: widget.currentPath,
            pathHistory: widget.pathHistory,
            onPathChanged: widget.onPathChanged,
            onPrefetchPath: widget.onPrefetchPath,
          )
        : _PathFieldView(
            currentPath: widget.currentPath,
            pathHistory: widget.pathHistory,
            onPathChanged: widget.onPathChanged,
            controllerCallback: (controller) {
              _pathFieldController = controller;
            },
            onPrefetchPath: widget.onPrefetchPath,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: spacing.inset(horizontal: 1, vertical: 0.5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              toggle,
              SizedBox(width: spacing.md),
              Expanded(child: content),
            ],
          ),
        ),
        if (widget.searchActive) ...[
          SizedBox(height: spacing.sm),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: spacing.inset(horizontal: 1, vertical: 0.75),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() => _searchExpanded = !_searchExpanded);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 16, color: theme.hintColor),
                        SizedBox(width: spacing.xs),
                        const Text('Search'),
                        const Spacer(),
                        if (widget.searchInProgress) ...[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          SizedBox(width: spacing.xs),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            tooltip: 'Stop search',
                            onPressed: widget.onSearchCancelled,
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.all(spacing.xs),
                              minimumSize: const Size(28, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                        Icon(
                          _searchExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  if (_searchExpanded) ...[
                    SizedBox(height: spacing.md),
                    _SearchPanel(
                      query: widget.searchQuery,
                      include: widget.searchInclude,
                      exclude: widget.searchExclude,
                      matchCase: widget.searchMatchCase,
                      matchWholeWord: widget.searchMatchWholeWord,
                      searchContents: widget.searchContents,
                      searchInProgress: widget.searchInProgress,
                      onSearchCancelled: widget.onSearchCancelled,
                      onQueryChanged: widget.onSearchQueryChanged,
                      onSearchSubmitted: widget.onSearchSubmitted,
                      onIncludeChanged: widget.onSearchIncludeChanged,
                      onExcludeChanged: widget.onSearchExcludeChanged,
                      onMatchCaseToggled: widget.onSearchMatchCaseChanged,
                      onMatchWholeWordToggled: widget.onSearchMatchWholeWordChanged,
                      onSearchContentsChanged: widget.onSearchContentsChanged,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BreadcrumbsView extends StatefulWidget {
  const _BreadcrumbsView({
    required this.currentPath,
    required this.pathHistory,
    required this.onPathChanged,
    this.onPrefetchPath,
  });

  final String currentPath;
  final Set<String> pathHistory;
  final ValueChanged<String> onPathChanged;
  final ValueChanged<String>? onPrefetchPath;

  @override
  State<_BreadcrumbsView> createState() => _BreadcrumbsViewState();
}

class _BreadcrumbsViewState extends State<_BreadcrumbsView> {
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
  void didUpdateWidget(covariant _BreadcrumbsView oldWidget) {
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
        onPressed: normalizedCurrent == '/' ? null : () => widget.onPathChanged('/'),
        suffix: _buildOptionalSeparator(
          context,
          '/',
          widget.onPrefetchPath,
        ),
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
      final agedOut = requestedAt != null &&
          DateTime.now().difference(requestedAt) > const Duration(seconds: 1);
      if (originalCount == null ||
          currentCount != originalCount ||
          agedOut) {
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
    required this.isResolved,
    required this.onRequested,
  });

  final String basePath;
  final List<String> Function() getChildren;
  final ValueChanged<String>? onPrefetchPath;
  final ValueChanged<String> onPathChanged;
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
    required this.iconColor,
    required this.isResolved,
    required this.onRequested,
  });

  final String basePath;
  final List<String> children;
  final List<String> Function() getChildren;
  final ValueChanged<String>? onPrefetchPath;
  final ValueChanged<String> onPathChanged;
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
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
      onTap: () => _handleTap(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
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
                  Icons.chevron_right,
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
    showMenu<String>(
      context: context,
      position: position,
      constraints: BoxConstraints(
        minWidth: renderBox.size.width,
        maxHeight: maxHeight,
      ),
      items: children
          .map(
            (child) => PopupMenuItem<String>(
              value: child,
              child: Text(child),
            ),
          )
          .toList(),
    ).then((value) {
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
                      color: _suffixHover ? innerHoverColor : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(6),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: spacing.xs),
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

class _PathFieldView extends StatefulWidget {
  const _PathFieldView({
    required this.currentPath,
    required this.pathHistory,
    required this.onPathChanged,
    required this.controllerCallback,
    this.onPrefetchPath,
  });

  final String currentPath;
  final Set<String> pathHistory;
  final ValueChanged<String> onPathChanged;
  final ValueChanged<TextEditingController> controllerCallback;
  final ValueChanged<String>? onPrefetchPath;

  @override
  State<_PathFieldView> createState() => _PathFieldViewState();
}

class _PathFieldViewState extends State<_PathFieldView> {
  String? _lastBasePath;
  TextEditingController? _controller;
  FocusNode? _focusNode;
  final FocusNode _keyboardFocusNode = FocusNode(skipTraversal: true);
  int _lastHistoryLength = 0;
  bool _suppressOptionsUpdate = false;
  bool _keyboardNavActive = false;
  bool _forcePreview = false;
  int? _lastHighlight;
  String? _previewText;
  String? _lastUserQuery;
  List<_PathSuggestion> _cachedOptions = const [];

  @override
  void initState() {
    super.initState();
    _lastHistoryLength = widget.pathHistory.length;
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PathFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _lastBasePath = null;
    }
    if (widget.pathHistory.length != _lastHistoryLength) {
      _lastHistoryLength = widget.pathHistory.length;
      _refreshOptionsIfNeeded();
    }
  }

  _PathSuggestion _buildSuggestion(String basePrefix, String entryName) {
    final replacement = basePrefix.isEmpty ? entryName : '$basePrefix$entryName';
    return _PathSuggestion(
      name: entryName,
      replacement: replacement,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Autocomplete<_PathSuggestion>(
      optionsBuilder: (textEditingValue) {
        if (_suppressOptionsUpdate) {
          _suppressOptionsUpdate = false;
          return _cachedOptions;
        }
        final input = textEditingValue.text.trim();
        _lastUserQuery = textEditingValue.text;
        final lastSlashIndex = input.lastIndexOf('/');
        final basePrefix = lastSlashIndex == -1
            ? ''
            : input.substring(0, lastSlashIndex + 1);
        final query = lastSlashIndex == -1
            ? input
            : input.substring(lastSlashIndex + 1);
        final basePath = basePrefix.isEmpty
            ? widget.currentPath
            : PathUtils.normalizePath(basePrefix, currentPath: widget.currentPath);
        final normalizedBasePath =
            PathUtils.normalizePath(basePath, currentPath: widget.currentPath);
        final prefix =
            normalizedBasePath == '/' ? '/' : '$normalizedBasePath/';
        final childNames = <String>{};
        for (final path in widget.pathHistory) {
          final normalized = PathUtils.normalizePath(path);
          if (normalized == normalizedBasePath || !normalized.startsWith(prefix)) {
            continue;
          }
          final remainder = normalized.substring(prefix.length);
          if (remainder.isEmpty) {
            continue;
          }
          final child = remainder.split('/').first;
          if (child.isNotEmpty) {
            childNames.add(child);
          }
        }
        if (normalizedBasePath != '/') {
          childNames.add('..');
        }
        final options = childNames
            .where((name) => query.isEmpty || name.startsWith(query))
            .map((name) => _buildSuggestion(basePrefix, name))
            .toList();
        _cachedOptions = options;
        return options;
      },
      displayStringForOption: (option) => option.replacement,
      initialValue: TextEditingValue(text: widget.currentPath),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        widget.controllerCallback(controller);
        _controller = controller;
        _focusNode = focusNode;
        return Focus(
          focusNode: _keyboardFocusNode,
          skipTraversal: true,
          onKey: (node, event) {
            if (event is RawKeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                    event.logicalKey == LogicalKeyboardKey.arrowUp)) {
              _keyboardNavActive = true;
              _forcePreview = true;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              prefixIcon: Icon(NerdIcon.folder.data, size: 16),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 24,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: spacing.xs * 0.75,
                horizontal: spacing.sm,
              ),
            ),
            onSubmitted: (_) => onFieldSubmitted(),
            onChanged: _handleInputChange,
          ),
        );
      },
      onSelected: (value) => widget.onPathChanged(
        PathUtils.normalizePath(value.replacement, currentPath: widget.currentPath),
      ),
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();
        final highlightIndex = AutocompleteHighlightedOption.of(context);
        _maybePreviewOption(highlightIndex, optionList);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: 360,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: optionList.length,
                itemBuilder: (context, index) {
                  final option = optionList[index];
                  final isHighlighted = index == highlightIndex;
                  return ListTile(
                    title: Text(option.name),
                    selected: isHighlighted,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleInputChange(String value) {
    if (widget.onPrefetchPath == null) {
      return;
    }
    _keyboardNavActive = false;
    _forcePreview = false;
    _lastHighlight = null;
    _previewText = null;
    final input = value.trim();
    final lastSlashIndex = input.lastIndexOf('/');
    final basePrefix = lastSlashIndex == -1
        ? ''
        : input.substring(0, lastSlashIndex + 1);
    final basePath = basePrefix.isEmpty
        ? widget.currentPath
        : PathUtils.normalizePath(basePrefix, currentPath: widget.currentPath);
    final normalizedBasePath =
        PathUtils.normalizePath(basePath, currentPath: widget.currentPath);
    if (_lastBasePath == normalizedBasePath) {
      return;
    }
    _lastBasePath = normalizedBasePath;
    widget.onPrefetchPath?.call(normalizedBasePath);
  }

  void _refreshOptionsIfNeeded() {
    final controller = _controller;
    final focusNode = _focusNode;
    if (controller == null || focusNode?.hasFocus != true) {
      return;
    }
    final text = controller.text;
    if (text.isEmpty || !text.contains('/')) {
      return;
    }
    final selection = controller.selection;
    controller.value = controller.value.copyWith(
      text: '$text ',
      selection: selection,
    );
    controller.value = controller.value.copyWith(
      text: text,
      selection: selection,
    );
  }

  void _maybePreviewOption(int highlightIndex, List<_PathSuggestion> options) {
    if (!_keyboardNavActive || options.isEmpty) {
      return;
    }
    if (highlightIndex < 0 || highlightIndex >= options.length) {
      return;
    }
    if (_lastHighlight == null && !_forcePreview) {
      _lastHighlight = highlightIndex;
      return;
    }
    if (!_forcePreview && _lastHighlight == highlightIndex) {
      return;
    }
    _lastHighlight = highlightIndex;
    _forcePreview = false;
    final preview = options[highlightIndex].replacement;
    if (_previewText == preview) {
      return;
    }
    _previewText = preview;
    _suppressOptionsUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controller;
      if (controller == null) {
        return;
      }
      controller.value = controller.value.copyWith(
        text: preview,
        selection: TextSelection.collapsed(offset: preview.length),
      );
    });
  }
}

class _PathSuggestion {
  const _PathSuggestion({
    required this.name,
    required this.replacement,
  });

  final String name;
  final String replacement;
}

class _SearchPanel extends StatefulWidget {
  const _SearchPanel({
    required this.query,
    required this.include,
    required this.exclude,
    required this.matchCase,
    required this.matchWholeWord,
    required this.searchContents,
    required this.searchInProgress,
    this.onSearchCancelled,
    required this.onQueryChanged,
    required this.onSearchSubmitted,
    required this.onIncludeChanged,
    required this.onExcludeChanged,
    required this.onMatchCaseToggled,
    required this.onMatchWholeWordToggled,
    required this.onSearchContentsChanged,
  });

  final String query;
  final String include;
  final String exclude;
  final bool matchCase;
  final bool matchWholeWord;
  final bool searchContents;
  final bool searchInProgress;
  final VoidCallback? onSearchCancelled;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<String>? onIncludeChanged;
  final ValueChanged<String>? onExcludeChanged;
  final VoidCallback? onMatchCaseToggled;
  final VoidCallback? onMatchWholeWordToggled;
  final ValueChanged<bool>? onSearchContentsChanged;

  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  late final TextEditingController _queryController;
  late final TextEditingController _includeController;
  late final TextEditingController _excludeController;
  bool _searchOptionsOpen = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.query);
    _includeController = TextEditingController(text: widget.include);
    _excludeController = TextEditingController(text: widget.exclude);
  }

  @override
  void didUpdateWidget(covariant _SearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _queryController.text != widget.query) {
      _queryController.text = widget.query;
    }
    if (oldWidget.include != widget.include &&
        _includeController.text != widget.include) {
      _includeController.text = widget.include;
    }
    if (oldWidget.exclude != widget.exclude &&
        _excludeController.text != widget.exclude) {
      _excludeController.text = widget.exclude;
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _includeController.dispose();
    _excludeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.searchInProgress) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'Stop search',
                    onPressed: widget.onSearchCancelled,
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.all(spacing.xs),
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.search, size: 16),
                    tooltip: 'Search',
                    onPressed: () {
                      widget.onSearchSubmitted?.call(_queryController.text);
                    },
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.all(spacing.xs),
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ToggleButtons(
                  isSelected: [_searchOptionsOpen],
                  onPressed: (_) {
                    setState(() {
                      _searchOptionsOpen = !_searchOptionsOpen;
                    });
                  },
                  borderRadius: BorderRadius.circular(2),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  children: [
                    Tooltip(
                      message: _searchOptionsOpen
                          ? 'Hide search options'
                          : 'Show search options',
                      waitDuration: const Duration(milliseconds: 400),
                      child: Icon(
                        _searchOptionsOpen ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                ToggleButtons(
                  isSelected: [!widget.searchContents, widget.searchContents],
                  onPressed: (index) {
                    widget.onSearchContentsChanged?.call(index == 1);
                  },
                  borderRadius: BorderRadius.circular(2),
                  constraints: const BoxConstraints(minWidth: 56, minHeight: 28),
                  children: const [
                    Tooltip(
                      message: 'Find by name',
                      waitDuration: Duration(milliseconds: 400),
                      child: Text('Name'),
                    ),
                    Tooltip(
                      message: 'Grep by content',
                      waitDuration: Duration(milliseconds: 400),
                      child: Text('Content'),
                    ),
                  ],
                ),
                ToggleButtons(
                  isSelected: [widget.matchWholeWord, widget.matchCase],
                  onPressed: (index) {
                    if (index == 0) {
                      widget.onMatchWholeWordToggled?.call();
                    } else {
                      widget.onMatchCaseToggled?.call();
                    }
                  },
                  borderRadius: BorderRadius.circular(2),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  children: const [
                    Tooltip(
                      message: 'Match whole word',
                      waitDuration: Duration(milliseconds: 400),
                      child: Icon(Icons.text_fields, size: 16),
                    ),
                    Tooltip(
                      message: 'Match case',
                      waitDuration: Duration(milliseconds: 400),
                      child: Icon(Icons.title, size: 16),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'Search',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'Search files and folders',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: spacing.xs,
                  horizontal: spacing.sm,
                ),
              ),
              onChanged: widget.onQueryChanged,
              onSubmitted: (value) => widget.onSearchSubmitted?.call(value),
            ),
          ],
          ),
        if (_searchOptionsOpen) ...[
          SizedBox(height: spacing.md),
          TextField(
            controller: _includeController,
            decoration: InputDecoration(
              labelText: 'Include',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: 'comma-separated patterns',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: spacing.xs,
                horizontal: spacing.sm,
              ),
            ),
            onChanged: widget.onIncludeChanged,
          ),
          SizedBox(height: spacing.md),
          TextField(
            controller: _excludeController,
            decoration: InputDecoration(
              labelText: 'Exclude',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: 'comma-separated patterns',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: spacing.xs,
                horizontal: spacing.sm,
              ),
            ),
            onChanged: widget.onExcludeChanged,
          ),
        ],
      ],
    );
  }
}

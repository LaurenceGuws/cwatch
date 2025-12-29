import 'package:flutter/material.dart';
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
      _pathFieldController?.text = widget.currentPath;
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
      constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
      children: const [
        Icon(Icons.alt_route, size: 16),
        Icon(Icons.text_fields, size: 16),
      ],
    );

    final content = widget.showBreadcrumbs
        ? _BreadcrumbsView(
            currentPath: widget.currentPath,
            onPathChanged: widget.onPathChanged,
            onNavigateToSubdirectory: widget.onNavigateToSubdirectory ?? () {},
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

class _BreadcrumbsView extends StatelessWidget {
  const _BreadcrumbsView({
    required this.currentPath,
    required this.onPathChanged,
    required this.onNavigateToSubdirectory,
  });

  final String currentPath;
  final ValueChanged<String> onPathChanged;
  final VoidCallback onNavigateToSubdirectory;

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
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final segments = currentPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final chips = <Widget>[
      ActionChip(
        label: const Text('/'),
        onPressed: () {
          if (currentPath != '/') {
            onPathChanged('/');
          }
        },
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(horizontal: spacing.xs),
        labelPadding: EdgeInsets.symmetric(horizontal: spacing.xs),
      ),
    ];

    var runningPath = '';
    for (final segment in segments) {
      runningPath += '/$segment';
      final normalizedRunningPath = _normalizePath(runningPath);
      chips.add(_buildSeparator());
      chips.add(
        Tooltip(
          message: segment,
          waitDuration: const Duration(milliseconds: 400),
          child: ActionChip(
            label: Text(
              segment,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            onPressed: () {
              onPathChanged(normalizedRunningPath);
            },
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: spacing.xs),
            labelPadding: EdgeInsets.symmetric(horizontal: spacing.xs),
          ),
        ),
      );
    }

    // Add "+" button to navigate deeper
    chips.add(_buildSeparator());
    chips.add(
      IconButton(
        icon: const Icon(Icons.add, size: 18),
        tooltip: 'Navigate to subdirectory',
        onPressed: onNavigateToSubdirectory,
        style: IconButton.styleFrom(
          padding: EdgeInsets.all(spacing.xs),
          minimumSize: const Size(28, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );

    final spacedChips = <Widget>[];
    for (final chip in chips) {
      if (spacedChips.isNotEmpty) {
        spacedChips.add(SizedBox(width: spacing.xs));
      }
      spacedChips.add(chip);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: spacing.xs * 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: spacedChips,
      ),
    );
  }

  Widget _buildSeparator() {
    return Icon(NerdIcon.arrowRight.data, size: 16);
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
  int _lastHistoryLength = 0;

  @override
  void initState() {
    super.initState();
    _lastHistoryLength = widget.pathHistory.length;
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
        final input = textEditingValue.text.trim();
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
        return childNames
            .where((name) => query.isEmpty || name.startsWith(query))
            .map((name) => _buildSuggestion(basePrefix, name))
            .toList();
      },
      displayStringForOption: (option) => option.replacement,
      initialValue: TextEditingValue(text: widget.currentPath),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        widget.controllerCallback(controller);
        _controller = controller;
        _focusNode = focusNode;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            prefixIcon: Icon(NerdIcon.folder.data, size: 16),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 32,
            ),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              vertical: spacing.xs,
              horizontal: spacing.sm,
            ),
          ),
          onSubmitted: (value) => widget.onPathChanged(
            PathUtils.normalizePath(value, currentPath: widget.currentPath),
          ),
          onChanged: _handleInputChange,
        );
      },
      onSelected: (value) => widget.onPathChanged(
        PathUtils.normalizePath(value.replacement, currentPath: widget.currentPath),
      ),
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: 360,
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map(
                      (option) => ListTile(
                        title: Text(option.name),
                        onTap: () => onSelected(option),
                      ),
                    )
                    .toList(),
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

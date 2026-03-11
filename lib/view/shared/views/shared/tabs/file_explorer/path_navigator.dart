import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';
import 'path_breadcrumbs_view.dart';
import 'path_search_panel.dart';

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
    this.showRowHeightControl = false,
    this.rowHeight = 36,
    this.onRowHeightChanged,
    this.onShowMenu,
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
  final bool showRowHeightControl;
  final double rowHeight;
  final ValueChanged<double>? onRowHeightChanged;
  final Future<String?> Function(
    RelativeRect position,
    List<PopupMenuEntry<String>> items,
    BoxConstraints constraints,
  )?
  onShowMenu;

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
          selection: TextSelection.collapsed(offset: widget.currentPath.length),
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
        ? PathBreadcrumbsView(
            currentPath: widget.currentPath,
            pathHistory: widget.pathHistory,
            onPathChanged: widget.onPathChanged,
            onPrefetchPath: widget.onPrefetchPath,
            onShowMenu: widget.onShowMenu,
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
                  PathSearchPanel(
                    query: widget.searchQuery,
                    include: widget.searchInclude,
                    exclude: widget.searchExclude,
                    matchCase: widget.searchMatchCase,
                    matchWholeWord: widget.searchMatchWholeWord,
                    searchContents: widget.searchContents,
                    searchExpanded: _searchExpanded,
                    searchInProgress: widget.searchInProgress,
                    onSearchCancelled: widget.onSearchCancelled,
                    onSearchExpandedChanged: (next) {
                      setState(() => _searchExpanded = next);
                    },
                    onQueryChanged: widget.onSearchQueryChanged,
                    onSearchSubmitted: widget.onSearchSubmitted,
                    onIncludeChanged: widget.onSearchIncludeChanged,
                    onExcludeChanged: widget.onSearchExcludeChanged,
                    onMatchCaseToggled: widget.onSearchMatchCaseChanged,
                    onMatchWholeWordToggled:
                        widget.onSearchMatchWholeWordChanged,
                    onSearchContentsChanged: widget.onSearchContentsChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (widget.showRowHeightControl) ...[
          SizedBox(height: spacing.sm),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: spacing.inset(horizontal: 1, vertical: 0.5),
              child: _RowHeightSlider(
                rowHeight: widget.rowHeight,
                onChanged: widget.onRowHeightChanged,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RowHeightSlider extends StatelessWidget {
  const _RowHeightSlider({required this.rowHeight, required this.onChanged});

  final double rowHeight;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final valueLabel = rowHeight.toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Row height', style: Theme.of(context).textTheme.bodyMedium),
            Text(valueLabel),
          ],
        ),
        Slider(
          value: rowHeight.clamp(24, 88).toDouble(),
          min: 24,
          max: 88,
          divisions: 16,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
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
    final replacement = basePrefix.isEmpty
        ? entryName
        : '$basePrefix$entryName';
    return _PathSuggestion(name: entryName, replacement: replacement);
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
        final lastSlashIndex = input.lastIndexOf('/');
        final basePrefix = lastSlashIndex == -1
            ? ''
            : input.substring(0, lastSlashIndex + 1);
        final query = lastSlashIndex == -1
            ? input
            : input.substring(lastSlashIndex + 1);
        final basePath = basePrefix.isEmpty
            ? widget.currentPath
            : PathUtils.normalizePath(
                basePrefix,
                currentPath: widget.currentPath,
              );
        final normalizedBasePath = PathUtils.normalizePath(
          basePath,
          currentPath: widget.currentPath,
        );
        final prefix = normalizedBasePath == '/' ? '/' : '$normalizedBasePath/';
        final childNames = <String>{};
        for (final path in widget.pathHistory) {
          final normalized = PathUtils.normalizePath(path);
          if (normalized == normalizedBasePath ||
              !normalized.startsWith(prefix)) {
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
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
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
        PathUtils.normalizePath(
          value.replacement,
          currentPath: widget.currentPath,
        ),
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
    final normalizedBasePath = PathUtils.normalizePath(
      basePath,
      currentPath: widget.currentPath,
    );
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
  const _PathSuggestion({required this.name, required this.replacement});

  final String name;
  final String replacement;
}

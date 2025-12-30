import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class PathSearchPanel extends StatefulWidget {
  const PathSearchPanel({
    super.key,
    required this.query,
    required this.include,
    required this.exclude,
    required this.matchCase,
    required this.matchWholeWord,
    required this.searchContents,
    required this.searchExpanded,
    required this.searchInProgress,
    this.onSearchCancelled,
    this.onSearchExpandedChanged,
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
  final bool searchExpanded;
  final bool searchInProgress;
  final VoidCallback? onSearchCancelled;
  final ValueChanged<bool>? onSearchExpandedChanged;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<String>? onIncludeChanged;
  final ValueChanged<String>? onExcludeChanged;
  final VoidCallback? onMatchCaseToggled;
  final VoidCallback? onMatchWholeWordToggled;
  final ValueChanged<bool>? onSearchContentsChanged;

  @override
  State<PathSearchPanel> createState() => _PathSearchPanelState();
}

class _PathSearchPanelState extends State<PathSearchPanel> {
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
  void didUpdateWidget(covariant PathSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        _queryController.text != widget.query) {
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
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
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
                          ToggleButtons(
                            isSelected: const [false],
                            onPressed: (_) {
                              widget.onSearchSubmitted?.call(
                                _queryController.text,
                              );
                            },
                            borderRadius: BorderRadius.circular(2),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            children: const [
                              Tooltip(
                                message: 'Search',
                                waitDuration: Duration(milliseconds: 400),
                                child: Icon(Icons.search, size: 16),
                              ),
                            ],
                          ),
                        ToggleButtons(
                          isSelected: [!widget.searchContents, widget.searchContents],
                          onPressed: (index) {
                            widget.onSearchContentsChanged?.call(index == 1);
                          },
                          borderRadius: BorderRadius.circular(2),
                          constraints: const BoxConstraints(
                            minWidth: 56,
                            minHeight: 28,
                          ),
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
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
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
                        ToggleButtons(
                          isSelected: [_searchOptionsOpen],
                          onPressed: (_) {
                            setState(() {
                              _searchOptionsOpen = !_searchOptionsOpen;
                            });
                          },
                          borderRadius: BorderRadius.circular(2),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          children: [
                            Tooltip(
                              message: _searchOptionsOpen
                                  ? 'Hide search options'
                                  : 'Show search options',
                              waitDuration: const Duration(milliseconds: 400),
                              child: Icon(
                                _searchOptionsOpen
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.searchExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  tooltip: widget.searchExpanded ? 'Collapse' : 'Expand',
                  onPressed: () {
                    widget.onSearchExpandedChanged?.call(!widget.searchExpanded);
                  },
                ),
              ],
            ),
            if (widget.searchExpanded)
              LayoutBuilder(
                builder: (context, constraints) {
                  final gap = spacing.sm;
                  final minFieldWidth = 220.0;
                  final availableWidth = constraints.maxWidth;
                  final showOptions = _searchOptionsOpen;
                  final canFitAll = showOptions &&
                      availableWidth >= (minFieldWidth * 3) + (gap * 2);
                  final canFitTwo = showOptions &&
                      availableWidth >= (minFieldWidth * 2) + gap;
                  Widget buildField({
                    required TextEditingController controller,
                    required String label,
                    required String hint,
                    ValueChanged<String>? onChanged,
                    ValueChanged<String>? onSubmitted,
                  }) {
                    return TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: label,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        hintText: hint,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: spacing.xs,
                          horizontal: spacing.sm,
                        ),
                      ),
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                    );
                  }

                  final queryField = buildField(
                    controller: _queryController,
                    label: 'Query',
                    hint: 'Search files and folders',
                    onChanged: widget.onQueryChanged,
                    onSubmitted: (value) =>
                        widget.onSearchSubmitted?.call(value),
                  );
                  final includeField = buildField(
                    controller: _includeController,
                    label: 'Include',
                    hint: 'comma-separated patterns',
                    onChanged: widget.onIncludeChanged,
                  );
                  final excludeField = buildField(
                    controller: _excludeController,
                    label: 'Exclude',
                    hint: 'comma-separated patterns',
                    onChanged: widget.onExcludeChanged,
                  );
                  if (!showOptions) {
                    return SizedBox(width: availableWidth, child: queryField);
                  }
                  if (canFitAll) {
                    final fieldWidth = (availableWidth - (gap * 2)) / 3;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(width: fieldWidth, child: queryField),
                        SizedBox(width: fieldWidth, child: includeField),
                        SizedBox(width: fieldWidth, child: excludeField),
                      ],
                    );
                  }
                  if (canFitTwo) {
                    final fieldWidth = (availableWidth - gap) / 2;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: availableWidth, child: queryField),
                        SizedBox(height: gap),
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(width: fieldWidth, child: includeField),
                            SizedBox(width: fieldWidth, child: excludeField),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: availableWidth, child: queryField),
                      SizedBox(height: gap),
                      includeField,
                      SizedBox(height: gap),
                      excludeField,
                    ],
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

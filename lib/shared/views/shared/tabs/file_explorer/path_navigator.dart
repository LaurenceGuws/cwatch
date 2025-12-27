import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/nerd_fonts.dart';

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
  });

  final String currentPath;
  final Set<String> pathHistory;
  final ValueChanged<String> onPathChanged;
  final bool showBreadcrumbs;
  final ValueChanged<bool>? onShowBreadcrumbsChanged;
  final VoidCallback? onNavigateToSubdirectory;

  @override
  State<PathNavigator> createState() => _PathNavigatorState();
}

class _PathNavigatorState extends State<PathNavigator> {
  TextEditingController? _pathFieldController;

  @override
  void didUpdateWidget(PathNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _pathFieldController?.text = widget.currentPath;
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
          );

    return Container(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
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
          padding: EdgeInsets.all(spacing.sm),
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );

    final spacedChips = <Widget>[];
    for (final chip in chips) {
      if (spacedChips.isNotEmpty) {
        spacedChips.add(SizedBox(width: spacing.sm));
      }
      spacedChips.add(chip);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
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

class _PathFieldView extends StatelessWidget {
  const _PathFieldView({
    required this.currentPath,
    required this.pathHistory,
    required this.onPathChanged,
    required this.controllerCallback,
  });

  final String currentPath;
  final Set<String> pathHistory;
  final ValueChanged<String> onPathChanged;
  final ValueChanged<TextEditingController> controllerCallback;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text;
        if (query.isEmpty) {
          return pathHistory;
        }
        return pathHistory.where((path) => path.startsWith(query));
      },
      initialValue: TextEditingValue(text: currentPath),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        controllerCallback(controller);
        controller.text = currentPath;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Path',
            prefixIcon: Icon(NerdIcon.folder.data),
          ),
          onSubmitted: (value) => onPathChanged(value),
        );
      },
      onSelected: (value) => onPathChanged(value),
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
                        title: Text(option),
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
}

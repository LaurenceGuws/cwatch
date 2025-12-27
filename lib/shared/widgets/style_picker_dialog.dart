import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StyleOption {
  const StyleOption({required this.key, required this.label});

  final String key;
  final String label;
}

/// Reusable picker dialog with search + live preview callbacks.
Future<String?> showStylePickerDialog({
  required BuildContext context,
  required String title,
  required List<StyleOption> options,
  required String selectedKey,
  ValueChanged<String>? onPreview,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return _StylePickerDialog(
        title: title,
        options: options,
        selectedKey: selectedKey,
        onPreview: onPreview,
      );
    },
  );
}

class _StylePickerDialog extends StatefulWidget {
  const _StylePickerDialog({
    required this.title,
    required this.options,
    required this.selectedKey,
    this.onPreview,
  });

  final String title;
  final List<StyleOption> options;
  final String selectedKey;
  final ValueChanged<String>? onPreview;

  @override
  State<_StylePickerDialog> createState() => _StylePickerDialogState();
}

class _StylePickerDialogState extends State<_StylePickerDialog> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final List<StyleOption> _options;
  late String _current;

  @override
  void initState() {
    super.initState();
    _options = List<StyleOption>.from(widget.options)
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    if (!_options.any((opt) => opt.key == widget.selectedKey)) {
      _options.add(
        StyleOption(key: widget.selectedKey, label: widget.selectedKey),
      );
    }
    _current = widget.selectedKey;
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {});
  }

  List<StyleOption> get _visible {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _options;
    final lower = query.toLowerCase();
    return _options
        .where(
          (opt) =>
              opt.label.toLowerCase().contains(lower) ||
              opt.key.toLowerCase().contains(lower),
        )
        .toList();
  }

  void _select(String key, {bool apply = false}) {
    if (_current != key) {
      setState(() => _current = key);
      widget.onPreview?.call(key);
    }
    if (apply) {
      _apply();
    }
  }

  void _apply() {
    Navigator.of(context).pop(_current);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appTheme.spacing;
    final visible = _visible;

    return Dialog(
      insetPadding: EdgeInsets.all(spacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.lg,
                vertical: spacing.md,
              ),
              color: scheme.surfaceContainerHigh,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${visible.length}',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.md,
                spacing.base * 2,
                spacing.md,
                spacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search themes',
                  prefixIcon: Icon(Icons.search, size: spacing.base * 4.5),
                  isDense: true,
                  contentPadding: EdgeInsets.all(spacing.md),
                ),
              ),
            ),
            Expanded(
              child: Scrollbar(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.sm,
                    spacing.md,
                    spacing.md,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: spacing.base * 1.5),
                  itemBuilder: (context, index) {
                    final option = visible[index];
                    final selected = option.key == _current;
                    final bg = selected
                        ? scheme.secondaryContainer
                        : scheme.surface;
                    final borderColor = selected
                        ? scheme.primary
                        : scheme.outlineVariant;
                    return InkWell(
                      onTap: () => _select(option.key),
                      onDoubleTap: () => _select(option.key, apply: true),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.md,
                          vertical: spacing.base * 2,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: spacing.base * 4.5,
                              color: selected ? scheme.primary : scheme.outline,
                            ),
                            SizedBox(width: spacing.base * 2.5),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: spacing.xs),
                                  Text(
                                    option.key,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.base * 2,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _current,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: spacing.md),
                  FilledButton(onPressed: _apply, child: const Text('Apply')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

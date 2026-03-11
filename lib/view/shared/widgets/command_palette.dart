import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/standard_empty_state.dart';
import 'lists/selectable_list_item.dart';

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.entries});

  final List<CommandPaletteEntry> entries;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late List<CommandPaletteEntry> _filtered;
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _filtered = widget.entries;
    _controller.addListener(_filter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries)) {
      _filtered = widget.entries;
      _filter();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_filter);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _controller.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.entries;
      } else {
        _filtered = widget.entries
            .where(
              (entry) =>
                  entry.label.toLowerCase().contains(query) ||
                  (entry.description?.toLowerCase().contains(query) ?? false) ||
                  entry.category.toLowerCase().contains(query),
            )
            .toList();
      }
      _selectedIndex = _filtered.isEmpty
          ? 0
          : _selectedIndex.clamp(0, _filtered.length - 1);
    });
  }

  void _select(int index, BuildContext context) {
    if (index < 0 || index >= _filtered.length) return;
    final itemExtent = context.scale(72);
    setState(() => _selectedIndex = index);
    _scrollController.animateTo(
      (index.clamp(0, _filtered.length - 1)) * itemExtent,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _activate(int index) {
    if (index < 0 || index >= _filtered.length) return;
    Navigator.of(context).pop(_filtered[index]);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _filtered;
    final queryActive = _controller.text.trim().isNotEmpty;

    return Dialog(
      elevation: 14,
      insetPadding: EdgeInsets.symmetric(
        horizontal: appTheme.spacing.base * 8,
        vertical: appTheme.spacing.base * 4,
      ),
      backgroundColor: scheme.surface.withValues(alpha: 0.98),
      shape: RoundedRectangleBorder(
        borderRadius: appTheme.section.surface.radius,
      ),
      child: CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.arrowDown): () {
            _select(
              (_selectedIndex + 1).clamp(
                0,
                (filtered.length - 1).clamp(0, 9999),
              ),
              context,
            );
          },
          SingleActivator(LogicalKeyboardKey.arrowUp): () {
            _select(
              (_selectedIndex - 1).clamp(
                0,
                (filtered.length - 1).clamp(0, 9999),
              ),
              context,
            );
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            _activate(_selectedIndex);
          },
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: context.scale(560),
            minWidth: context.scale(680),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: appTheme.spacing.inset(horizontal: 2.25, vertical: 1.75),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.keyboard_command_key,
                          size: appTheme.iconSizes.medium,
                          color: scheme.primary,
                        ),
                        SizedBox(width: appTheme.spacing.sm),
                        Expanded(
                          child: Text(
                            'Command palette',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          queryActive
                              ? '${filtered.length} matches'
                              : '${widget.entries.length} commands',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: appTheme.spacing.sm),
                    Text(
                      'Search app and module actions. Use arrows to move and Enter to run the selected command.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: appTheme.spacing.lg),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Search commands, categories, or descriptions',
                        prefixIcon: Icon(
                          Icons.search,
                          size: appTheme.iconSizes.medium,
                        ),
                        suffixIcon: queryActive
                            ? IconButton(
                                tooltip: 'Clear search',
                                onPressed: () => _controller.clear(),
                                icon: const Icon(Icons.close),
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.scale(14)),
                          borderSide: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.scale(14)),
                          borderSide: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.scale(14)),
                          borderSide: BorderSide(color: scheme.primary),
                        ),
                      ),
                      onSubmitted: (_) => _activate(_selectedIndex),
                      onEditingComplete: () {},
                    ),
                  ],
                ),
              ),
              Divider(height: appTheme.dimensions.dividerHeight),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(appTheme.spacing.xl),
                          child: StandardEmptyState(
                            icon: Icons.search_off,
                            message: queryActive
                                ? 'No matching commands. Try a broader term or search by category instead.'
                                : 'No commands are available right now.',
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: appTheme.spacing.lg,
                          vertical: appTheme.spacing.md,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => SizedBox(
                          height: appTheme.spacing.sm,
                        ),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final selected = index == _selectedIndex;

                          return DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                context.scale(14),
                              ),
                              border: Border.all(
                                color: selected
                                    ? scheme.primary.withValues(alpha: 0.28)
                                    : scheme.outlineVariant.withValues(alpha: 0.22),
                              ),
                              color: selected
                                  ? scheme.primary.withValues(alpha: 0.08)
                                  : scheme.surfaceContainerHighest.withValues(
                                      alpha: 0.16,
                                    ),
                            ),
                            child: SelectableListItem(
                              title: entry.label,
                              subtitle: entry.description,
                              selected: selected,
                              onTap: () => _activate(index),
                              leading: entry.icon != null
                                  ? Icon(
                                      entry.icon,
                                      size: appTheme.iconSizes.medium,
                                      color: selected
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    )
                                  : null,
                              trailing: Container(
                                padding: appTheme.spacing.inset(
                                  horizontal: 1.5,
                                  vertical: 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? scheme.primary.withValues(alpha: 0.12)
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(
                                    context.scale(999),
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? scheme.primary.withValues(alpha: 0.24)
                                        : scheme.outlineVariant.withValues(
                                            alpha: 0.25,
                                          ),
                                  ),
                                ),
                                child: Text(
                                  entry.category,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: selected
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showCommandPalette(
  BuildContext context, {
  required List<CommandPaletteEntry> entries,
}) async {
  final result = await showDialog<CommandPaletteEntry>(
    context: context,
    barrierDismissible: true,
    builder: (context) => CommandPalette(entries: entries),
  );
  if (result != null) {
    await result.onSelected();
  }
}

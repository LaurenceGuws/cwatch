import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
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
    final itemExtent = context.scale(64);
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
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;
    return Dialog(
      elevation: 10,
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
            maxHeight: context.scale(520),
            minWidth: context.scale(640),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: appTheme.spacing.inset(horizontal: 3, vertical: 2),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a command…',
                    prefixIcon: Icon(Icons.search, size: appTheme.iconSizes.medium),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _activate(_selectedIndex),
                  onEditingComplete: () {},
                ),
              ),
              Divider(height: appTheme.dimensions.dividerHeight),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(appTheme.spacing.xl),
                          child: Text(
                            'No commands match your search.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => Divider(
                          height: appTheme.dimensions.dividerHeight,
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final selected = index == _selectedIndex;

                          return SelectableListItem(
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
                                horizontal: 2,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(2 * context.zoomFactor),
                              ),
                              child: Text(
                                entry.category,
                                style: Theme.of(context).textTheme.labelSmall,
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

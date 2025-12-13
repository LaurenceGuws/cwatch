import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/command_palette_registry.dart';
import '../theme/app_theme.dart';

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
  static const double _itemExtent = 64;
  int? _pointerIndex;
  bool _pointerActive = false;

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

  void _select(int index) {
    if (index < 0 || index >= _filtered.length) return;
    setState(() => _selectedIndex = index);
    _scrollController.animateTo(
      (index.clamp(0, _filtered.length - 1)) * _itemExtent,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      backgroundColor: scheme.surface.withValues(alpha: 0.98),
      shape: RoundedRectangleBorder(
        borderRadius: appTheme.section.surface.radius,
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            _select(
              (_selectedIndex + 1).clamp(
                0,
                (filtered.length - 1).clamp(0, 9999),
              ),
            );
          },
          const SingleActivator(LogicalKeyboardKey.arrowUp): () {
            _select(
              (_selectedIndex - 1).clamp(
                0,
                (filtered.length - 1).clamp(0, 9999),
              ),
            );
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            _activate(_selectedIndex);
          },
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520, minWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a command…',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.8,
                    ),
                  ),
                  onSubmitted: (_) => _activate(_selectedIndex),
                  onEditingComplete: () {},
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
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
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final selected = index == _selectedIndex;
                          final hovered =
                              _pointerActive && _pointerIndex == index;
                          return MouseRegion(
                            onEnter: (_) => setState(() {
                              _pointerActive = true;
                              _pointerIndex = index;
                            }),
                            onExit: (_) => setState(() {
                              _pointerActive = false;
                              _pointerIndex = null;
                            }),
                            child: InkWell(
                              onTap: () => _activate(index),
                              child: Container(
                                height: _itemExtent,
                                color: selected
                                    ? scheme.primary.withValues(alpha: 0.08)
                                    : hovered
                                    ? scheme.surfaceContainerHighest.withValues(
                                        alpha: 0.5,
                                      )
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (entry.icon != null) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                          top: 2,
                                        ),
                                        child: Icon(
                                          entry.icon,
                                          size: 18,
                                          color: selected
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.label,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          if (entry.description != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Text(
                                                entry.description!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        entry.category,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ),
                                  ],
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

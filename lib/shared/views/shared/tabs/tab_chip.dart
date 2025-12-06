import 'package:flutter/material.dart';

import '../../../../models/ssh_host.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';

class TabChipOption {
  const TabChipOption({
    required this.label,
    required this.onSelected,
    this.icon,
    this.enabled = true,
    this.color,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool enabled;
  final Color? color;
}

class TabOptionsController extends ValueNotifier<List<TabChipOption>> {
  TabOptionsController([super.value = const []]);

  bool get isDisposed => _disposed;
  bool _disposed = false;

  void update(List<TabChipOption> options) {
    if (_disposed) {
      return;
    }
    value = options;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class CompositeTabOptionsController extends TabOptionsController {
  CompositeTabOptionsController([super.value = const []]);

  final List<TabChipOption> _baseOptions = [];
  final List<TabChipOption> _overlayOptions = [];

  void updateBase(List<TabChipOption> options) {
    _baseOptions
      ..clear()
      ..addAll(options);
    _refresh();
  }

  void updateOverlay(List<TabChipOption> options) {
    _overlayOptions
      ..clear()
      ..addAll(options);
    _refresh();
  }

  void _refresh() {
    if (isDisposed) {
      return;
    }
    value = List.unmodifiable([..._baseOptions, ..._overlayOptions]);
  }
}

class TabCloseWarning {
  const TabCloseWarning({
    required this.title,
    required this.message,
    this.confirmLabel = 'Close tab',
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
}

class TabChip extends StatelessWidget {
  const TabChip({
    super.key,
    required this.host,
    required this.label,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    this.onRename,
    this.options = const [],
    this.closeWarning,
    this.closable = true,
    this.dragIndex,
  });

  final SshHost host;
  final String label;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final VoidCallback? onRename;
  final List<TabChipOption> options;
  final TabCloseWarning? closeWarning;
  final bool closable;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final chipStyle = appTheme.tabChip.style(
      selected: selected,
      spacing: appTheme.spacing,
    );
    final foreground = chipStyle.foreground;
    final spacing = appTheme.spacing;
    final menuOptions = _buildMenuOptions();
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: spacing.xs * 0.2,
        vertical: spacing.xs * 0.15,
      ),
      constraints: BoxConstraints(
        maxHeight: spacing.base * 2.5,
      ),
      padding: chipStyle.padding,
      decoration: BoxDecoration(
        color: chipStyle.background,
        borderRadius: chipStyle.borderRadius,
        border: Border.all(color: chipStyle.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tooltip(
            message: dragIndex != null ? 'Drag to reorder' : 'Drag handle',
            child: _TabChipAction(
              hoverColor: foreground.withValues(alpha: 0.12),
              padding: const EdgeInsets.all(2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              child: _DragHandle(
                dragIndex: dragIndex,
                foreground: foreground,
              ),
            ),
          ),
          SizedBox(width: spacing.xs),
          Flexible(
            child: InkWell(
              onTap: onSelect,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  Text(
                    ' ',
                    style: appTheme.typography.tabLabel.copyWith(color: Colors.transparent),
                  ),
                  Flexible(
                    child: Text(
                      title,
                      style: appTheme.typography.tabLabel.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: spacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOptionsButton(foreground, menuOptions),
              SizedBox(width: spacing.xs),
              _TabChipAction(
                hoverColor: foreground.withValues(alpha: 0.12),
                child: IconButton(
                  icon: Icon(NerdIcon.close.data, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: closable ? 'Close tab' : 'Cannot close tab',
                  visualDensity: VisualDensity.compact,
                  splashRadius: 16,
                  onPressed: closable ? () => _handleClose(context) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<TabChipOption> _buildMenuOptions() {
    return [
      TabChipOption(
        label: 'Rename tab',
        icon: NerdIcon.pencil.data,
        enabled: onRename != null,
        onSelected: onRename ?? () {},
      ),
      ...options,
    ];
  }

  Widget _buildOptionsButton(
    Color foreground,
    List<TabChipOption> menuOptions,
  ) {
    return _TabChipAction(
      hoverColor: foreground.withValues(alpha: 0.12),
      child: PopupMenuButton<int>(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        tooltip: 'Tab options',
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Icon(Icons.more_vert, size: 16, color: foreground),
          ),
        ),
        onSelected: (value) => menuOptions[value].onSelected(),
        itemBuilder: (context) {
          return List.generate(menuOptions.length, (index) {
            final option = menuOptions[index];
            final textStyle =
                option.color != null ? TextStyle(color: option.color) : null;
            return PopupMenuItem<int>(
              value: index,
              enabled: option.enabled,
              child: Row(
                children: [
                  if (option.icon != null) ...[
                    Icon(option.icon, size: 18, color: option.color),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    option.label,
                    style: textStyle,
                  ),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  Future<void> _handleClose(BuildContext context) async {
    final shouldClose =
        closeWarning == null || await _showCloseWarning(context);
    if (!shouldClose) {
      return;
    }
    onClose();
  }

  Future<bool> _showCloseWarning(BuildContext context) async {
    final warning = closeWarning!;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(warning.title),
          content: Text(warning.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(warning.cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(warning.confirmLabel),
            ),
          ],
        );
      },
    );
    return result == true;
  }

}

class _TabChipAction extends StatefulWidget {
  const _TabChipAction({
    required this.child,
    required this.hoverColor,
    this.padding = const EdgeInsets.all(2),
    this.shape = const CircleBorder(),
  });

  final Widget child;
  final Color hoverColor;
  final EdgeInsetsGeometry padding;
  final ShapeBorder shape;

  @override
  State<_TabChipAction> createState() => _TabChipActionState();
}

class _TabChipActionState extends State<_TabChipAction> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _hovering ? widget.hoverColor : Colors.transparent,
          shape: widget.shape is CircleBorder ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.shape is RoundedRectangleBorder
              ? (widget.shape as RoundedRectangleBorder).borderRadius
              : null,
        ),
        child: widget.child,
      ),
    );
  }

  void _setHovering(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }
}

class _DragHandle extends StatefulWidget {
  const _DragHandle({
    required this.dragIndex,
    required this.foreground,
  });

  final int? dragIndex;
  final Color foreground;

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle> {
  final ValueNotifier<bool> _dragActive = ValueNotifier(false);

  void _setDragActive(bool value) {
    _dragActive.value = value;
  }

  Widget get _handle => SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: _dragActive,
            builder: (context, active, child) {
              final icon = active ? NerdIcon.dragSelect.data : NerdIcon.drag.data;
              final color = active
                  ? widget.foreground
                  : widget.foreground.withValues(alpha: 0.4);
              return Icon(icon, size: 16, color: color);
            },
          ),
        ),
      );

  @override
  void dispose() {
    _dragActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dragIndex == null) {
      return _handle;
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _setDragActive(true),
      onPointerUp: (_) => _setDragActive(false),
      onPointerCancel: (_) => _setDragActive(false),
      child: ReorderableDragStartListener(
        index: widget.dragIndex!,
        child: _handle,
      ),
    );
  }
}

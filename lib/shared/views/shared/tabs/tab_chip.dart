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

class TabChip extends StatefulWidget {
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
  State<TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<TabChip> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final spacing = appTheme.spacing;
    final chipStyle = appTheme.tabChip.style(
      selected: widget.selected,
      spacing: spacing,
    );
    final bleed = spacing.xs * 0.1;
    final foreground = widget.selected
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
    final primaryActionColor = colorScheme.primary;
    final primaryActionHover = colorScheme.onSurface.withValues(alpha: 0.08);
    final closeColor = colorScheme.error;
    final closeHover = closeColor.withValues(alpha: 0.12);
    colorScheme.surfaceContainerHighest.withValues(alpha: 0.38);
    final hoverColor =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final contentBackground = appTheme.section.toolbarBackground;
    final background = widget.selected
        ? contentBackground
        : (_hovering ? hoverColor : Colors.transparent);
    final borderColor = widget.selected
        ? colorScheme.outlineVariant.withValues(alpha: 0.5)
        : Colors.transparent;
    final radius = BorderRadius.zero;
    final boxShadow = widget.selected
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 10,
              spreadRadius: 0.15,
              offset: const Offset(0, 2),
            ),
          ]
        : const <BoxShadow>[];
    final menuOptions = _buildMenuOptions();
    final padding = EdgeInsets.only(
      left: chipStyle.padding.left + spacing.xs * 0.6,
      right: chipStyle.padding.right + spacing.xs * 0.6,
      top: chipStyle.padding.top + spacing.xs * 0.1,
      bottom: 0,
    );

    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: Transform.translate(
        offset: Offset(0, widget.selected ? -bleed : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.fromLTRB(
            spacing.xs * 0.45,
            spacing.xs * 0.4,
            spacing.xs * 0.45,
            0,
          ),
          padding: EdgeInsets.zero,
          child: CustomPaint(
            painter: _TabLipPainter(
              background: background,
              borderColor: borderColor,
              boxShadow: boxShadow,
              radius: radius,
              lipDepth: spacing.base * 1.2,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: padding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: widget.dragIndex != null
                            ? 'Drag to reorder'
                            : 'Drag handle',
                        child: _TabChipAction(
                          hoverColor: primaryActionHover,
                          padding: const EdgeInsets.all(2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _DragHandle(
                            dragIndex: widget.dragIndex,
                            color: primaryActionColor,
                            inactiveColor:
                                primaryActionColor.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.xs),
                      Flexible(
                        child: InkWell(
                          onTap: widget.onSelect,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.icon, size: 18, color: foreground),
                              Text(
                                ' ',
                                style: appTheme.typography.tabLabel.copyWith(
                                  color: Colors.transparent,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  widget.title,
                                  style: appTheme.typography.tabLabel.copyWith(
                                    color: foreground,
                                    fontWeight: widget.selected
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
                          _buildOptionsButton(
                            primaryActionColor,
                            primaryActionHover,
                            menuOptions,
                          ),
                          SizedBox(width: spacing.xs),
                          _TabChipAction(
                            hoverColor: closeHover,
                            child: IconButton(
                              icon: Icon(
                                NerdIcon.close.data,
                                size: 16,
                                color: closeColor,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: widget.closable
                                  ? 'Close tab'
                                  : 'Cannot close tab',
                              visualDensity: VisualDensity.compact,
                              splashRadius: 16,
                              disabledColor:
                                  closeColor.withValues(alpha: 0.4),
                              onPressed: widget.closable
                                  ? () => _handleClose(context)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.selected)
                  Positioned(
                    left: spacing.xs,
                    right: spacing.xs,
                    top: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  bottom: 4,
                  right: 0,
                  child: Container(
                    width: 1,
                    color: colorScheme.outlineVariant.withValues(
                      alpha: widget.selected
                          ? 0.2
                          : (_hovering ? 0.35 : 0.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<TabChipOption> _buildMenuOptions() {
    return [
      TabChipOption(
        label: 'Rename tab',
        icon: NerdIcon.pencil.data,
        enabled: widget.onRename != null,
        onSelected: widget.onRename ?? () {},
      ),
      ...widget.options,
    ];
  }

  Widget _buildOptionsButton(
    Color iconColor,
    Color hoverColor,
    List<TabChipOption> menuOptions,
  ) {
    return _TabChipAction(
      hoverColor: hoverColor,
      child: PopupMenuButton<int>(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        tooltip: 'Tab options',
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Icon(Icons.more_vert, size: 16, color: iconColor),
          ),
        ),
        onSelected: (value) => menuOptions[value].onSelected(),
        itemBuilder: (context) {
          return List.generate(menuOptions.length, (index) {
            final option = menuOptions[index];
            final textStyle = option.color != null
                ? TextStyle(color: option.color)
                : null;
            return PopupMenuItem<int>(
              value: index,
              enabled: option.enabled,
              child: Row(
                children: [
                  if (option.icon != null) ...[
                    Icon(option.icon, size: 18, color: option.color),
                    const SizedBox(width: 8),
                  ],
                  Text(option.label, style: textStyle),
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
        widget.closeWarning == null || await _showCloseWarning(context);
    if (!shouldClose) {
      return;
    }
    widget.onClose();
  }

  Future<bool> _showCloseWarning(BuildContext context) async {
    final warning = widget.closeWarning!;
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
          shape: widget.shape is CircleBorder
              ? BoxShape.circle
              : BoxShape.rectangle,
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
    required this.color,
    required this.inactiveColor,
  });

  final int? dragIndex;
  final Color color;
  final Color inactiveColor;

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
          final color = active ? widget.color : widget.inactiveColor;
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

class _TabLipPainter extends CustomPainter {
  _TabLipPainter({
    required this.background,
    required this.borderColor,
    required this.boxShadow,
    required this.radius,
    required this.lipDepth,
  });

  final Color background;
  final Color borderColor;
  final List<BoxShadow> boxShadow;
  final BorderRadius radius;
  final double lipDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final rTopLeft = radius.topLeft.x;
    final rTopRight = radius.topRight.x;
    final rBottomLeft = radius.bottomLeft.x;
    final rBottomRight = radius.bottomRight.x;
    final lip = lipDepth;
    final height = size.height;
    final bottomY = height - lip;

    Path buildPath() {
      final path = Path();
      path.moveTo(rTopLeft, 0);
      path.lineTo(size.width - rTopRight, 0);
      path.quadraticBezierTo(size.width, 0, size.width, rTopRight);
      path.lineTo(size.width, bottomY - rBottomRight);
      // Right corner flares outward/down.
      path.quadraticBezierTo(
        size.width + rBottomRight * 0.4,
        bottomY + lip * 0.65,
        size.width - rBottomRight * 0.2,
        bottomY + lip * 0.9,
      );
      // Center bow.
      path.quadraticBezierTo(
        size.width * 0.55,
        bottomY + lip,
        size.width * 0.5,
        bottomY + lip,
      );
      path.quadraticBezierTo(
        size.width * 0.45,
        bottomY + lip,
        rBottomLeft * 0.2,
        bottomY + lip * 0.9,
      );
      // Left corner flares outward/down.
      path.quadraticBezierTo(
        -rBottomLeft * 0.4,
        bottomY + lip * 0.65,
        0,
        bottomY - rBottomLeft,
      );
      path.lineTo(0, rTopLeft);
      path.quadraticBezierTo(0, 0, rTopLeft, 0);
      path.close();
      return path;
    }

    final path = buildPath();

    for (final shadow in boxShadow) {
      final shadowPaint = Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          shadow.blurRadius,
        );
      final shadowPath = path.shift(shadow.offset);
      canvas.drawPath(shadowPath, shadowPaint);
    }

    final paintFill = Paint()..color = background;
    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintBorder);
  }

  @override
  bool shouldRepaint(covariant _TabLipPainter oldDelegate) {
    return background != oldDelegate.background ||
        borderColor != oldDelegate.borderColor ||
        radius != oldDelegate.radius ||
        lipDepth != oldDelegate.lipDepth ||
        boxShadow != oldDelegate.boxShadow;
  }
}

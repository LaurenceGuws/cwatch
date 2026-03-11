import 'package:flutter/material.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';

class FloatingSettingsWindow extends StatefulWidget {
  const FloatingSettingsWindow({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    this.initialPosition,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final Offset? initialPosition;

  @override
  State<FloatingSettingsWindow> createState() => _FloatingSettingsWindowState();
}

class _FloatingSettingsWindowState extends State<FloatingSettingsWindow> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition ?? const Offset(20, 20);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const panelRadius = Radius.circular(12);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          elevation: 12,
          shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.22),
          borderRadius: const BorderRadius.all(panelRadius),
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surface,
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: const BorderRadius.all(panelRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      Material(
                        color: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: InkWell(
                          onTap: widget.onClose,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              NerdIcon.close.data,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Theme(
                      data: theme.copyWith(
                        dividerColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                      child: DefaultTextStyle.merge(
                        style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                            ) ??
                            const TextStyle(height: 1.35),
                        child: widget.child,
                      ),
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
}

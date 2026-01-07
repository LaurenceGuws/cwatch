import 'package:flutter/material.dart';
import '../../../../theme/nerd_fonts.dart';

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
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface,
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(NerdIcon.close.data, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: widget.child,
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

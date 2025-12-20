import 'package:flutter/material.dart';

/// Reusable settings section widget with collapse/expand support.
class SettingsSection extends StatefulWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final String? description;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant SettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        _expanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        widget.description != null && widget.description!.trim().isNotEmpty;
    final iconColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: BorderRadius.circular(2),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 18,
                      color: iconColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (hasDescription)
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 18),
                        color: iconColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: null,
                        onPressed: () => _showDescription(context),
                      ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 4),
              const Divider(height: 12),
              widget.child,
            ],
          ],
        ),
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  void _showDescription(BuildContext context) {
    if (widget.description == null || widget.description!.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.title),
        content: Text(widget.description!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

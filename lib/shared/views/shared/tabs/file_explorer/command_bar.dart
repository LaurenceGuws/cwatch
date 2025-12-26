import 'package:flutter/material.dart';
import '../../../../theme/nerd_fonts.dart';
import '../../../../theme/app_theme.dart';

/// Command bar for executing ad-hoc SSH commands
class CommandBar extends StatefulWidget {
  const CommandBar({
    super.key,
    required this.hostName,
    required this.onCommandSubmitted,
  });

  final String hostName;
  final ValueChanged<String> onCommandSubmitted;

  @override
  State<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<CommandBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.appTheme.spacing;
    return Container(
      padding: spacing.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(spacing.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Run command',
                prefixText: 'ssh ${widget.hostName}\$ ',
                border: InputBorder.none,
              ),
              onSubmitted: (value) {
                widget.onCommandSubmitted(value);
                _controller.clear();
              },
            ),
          ),
          IconButton(
            tooltip: 'Run command',
            icon: Icon(NerdIcon.terminal.data),
            onPressed: () {
              final command = _controller.text.trim();
              if (command.isNotEmpty) {
                widget.onCommandSubmitted(command);
                _controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}

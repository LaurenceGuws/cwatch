import 'package:flutter/material.dart';
import '../../../../theme/nerd_fonts.dart';

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
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: 'Run command',
        prefixText: 'ssh ${widget.hostName}\$ ',
        suffixIcon: IconButton(
          icon: Icon(NerdIcon.terminal.data),
          onPressed: () {
            final command = _controller.text.trim();
            if (command.isNotEmpty) {
              widget.onCommandSubmitted(command);
              _controller.clear();
            }
          },
        ),
      ),
      onSubmitted: (value) {
        widget.onCommandSubmitted(value);
        _controller.clear();
      },
    );
  }
}


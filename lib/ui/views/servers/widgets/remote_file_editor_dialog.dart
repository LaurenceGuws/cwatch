import 'package:flutter/material.dart';

class RemoteFileEditorDialog extends StatefulWidget {
  const RemoteFileEditorDialog({
    super.key,
    required this.path,
    required this.initialContent,
    this.helperText,
  });

  final String path;
  final String initialContent;
  final String? helperText;

  @override
  State<RemoteFileEditorDialog> createState() => _RemoteFileEditorDialogState();
}

class _RemoteFileEditorDialogState extends State<RemoteFileEditorDialog> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() {
      if (!_dirty && _controller.text != widget.initialContent) {
        setState(() {
          _dirty = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editing ${widget.path}'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.helperText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(widget.helperText!),
              ),
            TextField(
              controller: _controller,
              maxLines: 20,
              minLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<String?>(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _dirty ? () => Navigator.of(context).pop(_controller.text) : null,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

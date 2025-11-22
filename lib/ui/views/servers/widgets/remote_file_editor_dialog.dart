import 'package:flutter/material.dart';

import '../../../theme/nerd_fonts.dart';
import 'code_highlighter.dart';
import 'syntax_editing_controller.dart';

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
  late final SyntaxEditingController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final language = languageFromPath(widget.path);
    final theme = CodeHighlightTheme.fromScheme(Theme.of(context).colorScheme);
    final highlighter = language != null
        ? HighlightSyntaxHighlighter(language: language, theme: theme)
        : PlainCodeHighlighter();
    _controller = SyntaxEditingController(
      text: widget.initialContent,
      syntaxHighlighter: highlighter,
    )..addListener(_handleTextChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = languageFromPath(widget.path);
    final theme = CodeHighlightTheme.fromScheme(Theme.of(context).colorScheme);
    final highlighter = language != null
        ? HighlightSyntaxHighlighter(language: language, theme: theme)
        : PlainCodeHighlighter();
    _controller.updateHighlighter(highlighter);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.85;
    final height = size.height * 0.75;
    final codeStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: NerdFonts.family,
      height: 1.35,
    );
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text('Editing ${widget.path}'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.helperText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(widget.helperText!),
              ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Scrollbar(
                        controller: _scrollController,
                        child: TextField(
                          controller: _controller,
                          scrollController: _scrollController,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                          style: codeStyle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 240,
                    child: _EditorInspector(
                      path: widget.path,
                      controller: _controller,
                      helperText: widget.helperText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<String?>(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _dirty
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
          icon: Icon(NerdIcon.cloudUpload.data),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _handleTextChange() {
    final dirty = _controller.text != widget.initialContent;
    if (dirty != _dirty) {
      setState(() {
        _dirty = dirty;
      });
    } else {
      setState(() {});
    }
  }
}

class _EditorInspector extends StatelessWidget {
  const _EditorInspector({
    required this.path,
    required this.controller,
    required this.helperText,
  });

  final String path;
  final TextEditingController controller;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = controller.text;
    final lines = content.isEmpty ? 0 : content.split('\n').length;
    final language = languageFromPath(path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('File info', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        _InspectorTile(label: 'Lines', value: '$lines'),
        _InspectorTile(label: 'Characters', value: '${content.length}'),
        _InspectorTile(label: 'Path', value: path),
        const SizedBox(height: 16),
        Text('Syntax highlighting', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          language != null ? 'Language: $language' : 'No highlighting',
          style: textTheme.bodySmall,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 16),
          Text('Notes', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(helperText!, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _InspectorTile extends StatelessWidget {
  const _InspectorTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.color?.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: 2),
          Text(value, style: theme.bodyMedium),
        ],
      ),
    );
  }
}

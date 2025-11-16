import 'package:flutter/material.dart';

import '../../../theme/nerd_fonts.dart';

class MergeConflictDialog extends StatefulWidget {
  const MergeConflictDialog({
    super.key,
    required this.remotePath,
    required this.local,
    required this.remote,
  });

  final String remotePath;
  final String local;
  final String remote;

  @override
  State<MergeConflictDialog> createState() => _MergeConflictDialogState();
}

class _MergeConflictDialogState extends State<MergeConflictDialog> {
  late final TextEditingController _mergedController;
  late final ScrollController _remoteController;
  late final ScrollController _localController;
  late final List<_DiffLine> _remoteDiffLines;
  late final List<_DiffLine> _localDiffLines;

  @override
  void initState() {
    super.initState();
    _mergedController = TextEditingController(text: widget.local);
    _remoteController = ScrollController();
    _localController = ScrollController();
    _remoteDiffLines = _buildDiffLines(widget.remote, widget.local);
    _localDiffLines = _buildDiffLines(widget.local, widget.remote);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirstDiff());
  }

  @override
  void dispose() {
    _mergedController.dispose();
    _remoteController.dispose();
    _localController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.8;
    final diffHeight = size.height * 0.4;
    final mergedHeight = size.height * 0.3;

    return AlertDialog(
      title: Text('Resolve conflicts for ${widget.remotePath}'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      content: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Remote file changed while you edited locally. Review differences and provide the merged result.'),
            const SizedBox(height: 16),
            SizedBox(
              height: diffHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _DiffPane(
                      title: 'Remote (server)',
                      lines: _remoteDiffLines,
                      controller: _remoteController,
                    ),
                  ),
                  const VerticalDivider(width: 16),
                  Expanded(
                    child: _DiffPane(
                      title: 'Local (cached)',
                      lines: _localDiffLines,
                      controller: _localController,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: mergedHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Merged result'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _mergedController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      style: const TextStyle(fontFamily: 'monospace'),
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
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(_mergedController.text),
          icon: Icon(NerdIcon.checkCircle.data),
          label: const Text('Apply Merge'),
        ),
      ],
    );
  }

  void _scrollToFirstDiff() {
    int remoteIndex = _remoteDiffLines.indexWhere((line) => line.type != DiffType.same);
    int localIndex = _localDiffLines.indexWhere((line) => line.type != DiffType.same);
    remoteIndex = remoteIndex == -1 ? _remoteDiffLines.length : remoteIndex;
    localIndex = localIndex == -1 ? _localDiffLines.length : localIndex;
    final targetIndex = remoteIndex < localIndex ? remoteIndex : localIndex;
    final offset = targetIndex * 20.0;
    if (_remoteController.hasClients) {
      _remoteController.jumpTo(offset.clamp(0, _remoteController.position.maxScrollExtent));
    }
    if (_localController.hasClients) {
      _localController.jumpTo(offset.clamp(0, _localController.position.maxScrollExtent));
    }
  }

  List<_DiffLine> _buildDiffLines(String content, String reference) {
    final lines = content.split('\n');
    final other = reference.split('\n');
    final maxLength = lines.length > other.length ? lines.length : other.length;
    final result = <_DiffLine>[];
    for (var i = 0; i < maxLength; i += 1) {
      final text = i < lines.length ? lines[i] : '[line missing]';
      final otherText = i < other.length ? other[i] : '';
      DiffType type;
      if (i >= lines.length) {
        type = DiffType.missing;
      } else if (i >= other.length) {
        type = DiffType.onlyHere;
      } else if (text == otherText) {
        type = DiffType.same;
      } else {
        type = DiffType.changed;
      }
      result.add(_DiffLine(text: text, type: type));
    }
    return result;
  }
}

class _DiffPane extends StatelessWidget {
  const _DiffPane({
    required this.title,
    required this.lines,
    required this.controller,
  });

  final String title;
  final List<_DiffLine> lines;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Scrollbar(
              controller: controller,
              thumbVisibility: true,
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.all(8),
                primary: false,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final colors = _colorsForType(line.type, context);
                  return Container(
                    color: colors.background,
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: Text(
                      line.text,
                      style: TextStyle(fontFamily: 'monospace', color: colors.foreground),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  _DiffColors _colorsForType(DiffType type, BuildContext context) {
    switch (type) {
      case DiffType.same:
        return _DiffColors(null, Theme.of(context).textTheme.bodyMedium?.color);
      case DiffType.changed:
        return _DiffColors(Colors.amber.shade100, Colors.black87);
      case DiffType.onlyHere:
        return _DiffColors(Colors.green.shade100, Colors.green.shade900);
      case DiffType.missing:
        return _DiffColors(Colors.red.shade100, Colors.red.shade900);
    }
  }
}

class _DiffLine {
  const _DiffLine({required this.text, required this.type});

  final String text;
  final DiffType type;
}

enum DiffType { same, changed, onlyHere, missing }

class _DiffColors {
  const _DiffColors(this.background, this.foreground);

  final Color? background;
  final Color? foreground;
}

import 'package:flutter/material.dart';

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.color?.withValues(alpha: 0.7);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: theme.bodySmall?.copyWith(color: muted)),
        ),
        Expanded(child: Text(value, style: theme.bodyMedium)),
      ],
    );
  }
}

Future<void> showFileInfoDialog({
  required BuildContext context,
  required String path,
  required String content,
  required String? language,
  required String? parserName,
  String? helperText,
}) async {
  final lines = content.isEmpty ? 0 : content.split('\n').length;
  final textTheme = Theme.of(context).textTheme;

  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('File Information'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Path', value: path),
          const SizedBox(height: 8),
          _InfoRow(label: 'Lines', value: '$lines'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Characters', value: '${content.length}'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Language', value: language ?? 'Unknown'),
          if (parserName != null) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Parser', value: parserName),
          ],
          if (helperText != null) ...[
            const SizedBox(height: 16),
            Text('Notes', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(helperText, style: textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

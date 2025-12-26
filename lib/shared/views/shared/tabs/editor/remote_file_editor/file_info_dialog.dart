import 'package:flutter/material.dart';

import 'package:cwatch/shared/theme/app_theme.dart';

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
  final spacing = context.appTheme.spacing;

  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('File Information'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Path', value: path),
          SizedBox(height: spacing.md),
          _InfoRow(label: 'Lines', value: '$lines'),
          SizedBox(height: spacing.md),
          _InfoRow(label: 'Characters', value: '${content.length}'),
          SizedBox(height: spacing.md),
          _InfoRow(label: 'Language', value: language ?? 'Unknown'),
          if (parserName != null) ...[
            SizedBox(height: spacing.md),
            _InfoRow(label: 'Parser', value: parserName),
          ],
          if (helperText != null) ...[
            SizedBox(height: spacing.xl),
            Text('Notes', style: textTheme.titleMedium),
            SizedBox(height: spacing.sm),
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

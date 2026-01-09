import 'package:flutter/material.dart';

import 'package:cwatch/shared/theme/app_theme.dart';

class RemoteFileInfoDialogContent extends StatelessWidget {
  const RemoteFileInfoDialogContent({
    super.key,
    required this.path,
    required this.content,
    required this.language,
    required this.parserName,
    required this.helperText,
  });

  final String path;
  final String content;
  final String? language;
  final String? parserName;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final lines = content.isEmpty ? 0 : content.split('\n').length;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appTheme.spacing;

    Widget infoRow(String label, String value) {
      final muted = textTheme.bodySmall?.color?.withValues(alpha: 0.7);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        infoRow('Path', path),
        SizedBox(height: spacing.md),
        infoRow('Lines', '$lines'),
        SizedBox(height: spacing.md),
        infoRow('Characters', '${content.length}'),
        SizedBox(height: spacing.md),
        infoRow('Language', language ?? 'Unknown'),
        if (parserName != null) ...[
          SizedBox(height: spacing.md),
          infoRow('Parser', parserName!),
        ],
        if (helperText != null) ...[
          SizedBox(height: spacing.xl),
          Text('Notes', style: textTheme.titleMedium),
          SizedBox(height: spacing.sm),
          Text(helperText!, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}

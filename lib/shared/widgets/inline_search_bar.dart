import 'package:flutter/material.dart';

class InlineSearchBar extends StatelessWidget {
  const InlineSearchBar({
    super.key,
    required this.controller,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search',
                border: InputBorder.none,
              ),
              onSubmitted: onSubmit,
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: onPrev,
          ),
          IconButton(
            tooltip: 'Next',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: onNext,
          ),
          IconButton(
            tooltip: 'Close search',
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

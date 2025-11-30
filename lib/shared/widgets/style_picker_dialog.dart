import 'package:flutter/material.dart';

class StyleOption {
  const StyleOption({required this.key, required this.label});

  final String key;
  final String label;
}

/// Reusable picker dialog with search + live preview callbacks.
Future<String?> showStylePickerDialog({
  required BuildContext context,
  required String title,
  required List<StyleOption> options,
  required String selectedKey,
  ValueChanged<String>? onPreview,
}) {
  final sorted = List<StyleOption>.from(options)
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      var current = selectedKey;
      final searchController = TextEditingController();
      final focusNode = FocusNode();

      List<StyleOption> filtered(String query) {
        if (query.trim().isEmpty) return sorted;
        final lower = query.toLowerCase();
        return sorted
            .where((opt) =>
                opt.label.toLowerCase().contains(lower) ||
                opt.key.toLowerCase().contains(lower))
            .toList();
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final visible = filtered(searchController.text);
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 420,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final option = visible[index];
                        final selected = option.key == current;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).iconTheme.color,
                          ),
                          title: Text(option.label),
                          subtitle: Text(
                            option.key,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                          onTap: () {
                            setState(() => current = option.key);
                            onPreview?.call(option.key);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(current),
                child: const Text('Use selection'),
              ),
            ],
          );
        },
      );
    },
  );
}

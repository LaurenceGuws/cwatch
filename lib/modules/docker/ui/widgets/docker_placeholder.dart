import 'package:flutter/material.dart';

class DockerPlaceholder extends StatelessWidget {
  const DockerPlaceholder({super.key, required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_queue, size: 48),
          const SizedBox(height: 12),
          const Text('Open Docker engines'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onActivate,
            child: const Text('Open Docker engines'),
          ),
        ],
      ),
    );
  }
}

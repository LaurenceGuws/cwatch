import 'package:flutter/material.dart';

import 'widgets/pluto_grid_demo.dart';

class ExperimentalView extends StatelessWidget {
  const ExperimentalView({super.key, this.leading});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) leading!,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Experimental', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Scratch space for isolated widget UX spikes.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const PlutoGridDemo(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

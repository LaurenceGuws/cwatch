import 'package:flutter/material.dart';

import '../../widgets/section_nav_bar.dart';

class DockerView extends StatelessWidget {
  const DockerView({super.key, this.leading});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionNavBar(title: 'Docker', tabs: const [], leading: leading),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Text(
                'Container Runtimes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                title: 'Status',
                body: 'Connect to local or remote Docker daemons to view containers.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add Docker Host'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}

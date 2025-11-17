import 'package:flutter/material.dart';

import '../../widgets/section_nav_bar.dart';

class KubernetesView extends StatelessWidget {
  const KubernetesView({super.key, this.leading});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionNavBar(title: 'Kubernetes', tabs: const [], leading: leading),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Text(
                'Clusters',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                title: 'Status',
                body: 'Register kubeconfigs to inspect nodes, pods, and workloads.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add Cluster'),
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

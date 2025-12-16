import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/wsl_distribution.dart';
import '../services/wsl_service_interface.dart';

class WslHome extends StatefulWidget {
  const WslHome({super.key, required this.service, this.leading});

  final WslService service;
  final Widget? leading;

  @override
  State<WslHome> createState() => _WslHomeState();
}

class _WslHomeState extends State<WslHome> {
  late Future<List<WslDistribution>> _distrosFuture;

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _distrosFuture = _loadDistributions();
  }

  Future<List<WslDistribution>> _loadDistributions() {
    if (!_isWindows) {
      return Future.value(const []);
    }
    return widget.service.listDistributions();
  }

  void _refresh() {
    setState(() {
      _distrosFuture = _loadDistributions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.leading != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: widget.leading,
                ),
              Text(
                'Windows Subsystem for Linux',
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (!_isWindows) {
      return _InfoCard(
        title: 'Unavailable on this platform',
        message: 'WSL is only available on Windows.',
        icon: Icons.info_outline,
      );
    }

    return FutureBuilder<List<WslDistribution>>(
      future: _distrosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _InfoCard(
            title: 'Failed to load WSL',
            message: snapshot.error.toString(),
            icon: Icons.error_outline,
            action: TextButton(onPressed: _refresh, child: const Text('Retry')),
          );
        }
        final distros = snapshot.data ?? const [];
        if (distros.isEmpty) {
          return _InfoCard(
            title: 'No distributions found',
            message:
                'Install a distribution with "wsl --install" or the '
                'Microsoft Store, then refresh.',
            icon: Icons.laptop_mac,
            action: TextButton(
              onPressed: _refresh,
              child: const Text('Refresh'),
            ),
          );
        }
        return ListView.separated(
          itemCount: distros.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final distro = distros[index];
            return ListTile(
              leading: Icon(
                distro.isDefault ? Icons.star : Icons.lan,
                color: distro.isDefault
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(distro.name),
              subtitle: Text(
                'State: ${distro.state} | Version: ${distro.version}',
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(title, style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodyMedium),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

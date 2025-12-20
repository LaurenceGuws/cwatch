import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/models/docker_context.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/modules/servers/services/host_distro_key.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/distro_icons.dart';
import 'package:cwatch/shared/widgets/distro_leading_slot.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
import 'package:cwatch/shared/widgets/lists/selectable_list_item.dart';
import 'docker_shared.dart';

class RemoteDockerStatus {
  const RemoteDockerStatus({
    required this.host,
    required this.available,
    required this.detail,
  });

  final SshHost host;
  final bool available;
  final String detail;
}

class EnginePicker extends StatefulWidget {
  const EnginePicker({
    super.key,
    required this.tabId,
    required this.contextsFuture,
    required this.cachedReady,
    required this.remoteStatusFuture,
    required this.remoteScanRequested,
    required this.onRefreshContexts,
    required this.onScanRemotes,
    required this.onOpenContext,
    required this.onOpenHost,
    required this.settingsController,
  });

  final String tabId;
  final Future<List<DockerContext>>? contextsFuture;
  final List<RemoteDockerStatus> cachedReady;
  final Future<List<RemoteDockerStatus>>? remoteStatusFuture;
  final bool remoteScanRequested;
  final VoidCallback onRefreshContexts;
  final VoidCallback onScanRemotes;
  final void Function(String contextName, Offset? anchor) onOpenContext;
  final void Function(SshHost host, Offset? anchor) onOpenHost;
  final AppSettingsController settingsController;

  @override
  State<EnginePicker> createState() => _EnginePickerState();
}

class _EnginePickerState extends State<EnginePicker> {
  String? _selectedContext;
  String? _selectedRemoteHost;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        FutureBuilder<List<DockerContext>>(
          future: widget.contextsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return ErrorCard(
                message: snapshot.error.toString(),
                onRetry: widget.onRefreshContexts,
              );
            }
            final contexts = snapshot.data ?? const <DockerContext>[];
            if (contexts.isEmpty) {
              return EmptyState(onRefresh: widget.onRefreshContexts);
            }
            final iconSize = _leadingIconSize(context);
            return SectionList(
              title: 'Local contexts',
              children: List.generate(contexts.length, (index) {
                final ctx = contexts[index];
                Offset? lastPointer;
                final isSelected = _selectedContext == ctx.name;
                void select() {
                  setState(() {
                    _selectedContext = ctx.name;
                    _selectedRemoteHost = null;
                  });
                }

                void open([Offset? anchor]) {
                  select();
                  widget.onOpenContext(ctx.name, anchor);
                }

                return SelectableListItem(
                  stripeIndex: index,
                  selected: isSelected,
                  title: ctx.name,
                  leading: Icon(
                    NerdIcon.docker.data,
                    size: iconSize,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  onTapDown: (details) => lastPointer = details.globalPosition,
                  onTap: () => select(),
                  onDoubleTap: () => open(lastPointer),
                  onLongPress: () => open(lastPointer),
                  onSecondaryTapDown: (details) => open(details.globalPosition),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 12),
        RemoteSection(
          remoteStatusFuture: widget.remoteStatusFuture,
          scanRequested: widget.remoteScanRequested,
          cachedReady: widget.cachedReady,
          onScan: widget.onScanRemotes,
          onOpenHost: (host, anchor) {
            setState(() {
              _selectedRemoteHost = host.name;
              _selectedContext = null;
            });
            widget.onOpenHost(host, anchor);
          },
          selectedHostName: _selectedRemoteHost,
          onSelectHost: (host, anchor) {
            setState(() {
              _selectedRemoteHost = host.name;
              _selectedContext = null;
            });
            if (anchor != null) {
              widget.onOpenHost(host, anchor);
            }
          },
          settingsController: widget.settingsController,
        ),
      ],
    );
  }
}

double _leadingIconSize(BuildContext context) {
  final titleSize = Theme.of(context).textTheme.titleMedium?.fontSize ?? 14;
  return titleSize * 1.9;
}

class RemoteSection extends StatelessWidget {
  const RemoteSection({
    super.key,
    required this.remoteStatusFuture,
    required this.scanRequested,
    required this.cachedReady,
    required this.onScan,
    required this.onOpenHost,
    required this.selectedHostName,
    required this.onSelectHost,
    required this.settingsController,
  });

  final Future<List<RemoteDockerStatus>>? remoteStatusFuture;
  final bool scanRequested;
  final List<RemoteDockerStatus> cachedReady;
  final VoidCallback onScan;
  final void Function(SshHost host, Offset? anchor) onOpenHost;
  final String? selectedHostName;
  final void Function(SshHost host, Offset? anchor) onSelectHost;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text('Servers', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: onScan,
                icon: Icon(icons.search),
                label: const Text('Scan'),
              ),
            ],
          ),
        ),
        if (!scanRequested)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: cachedReady.isEmpty
                ? const Text(
                    'Scan to check which servers have Docker available.',
                  )
                : RemoteHostList(
                    hosts: cachedReady,
                    onOpenHost: onOpenHost,
                    selectedHostName: selectedHostName,
                    onSelectHost: onSelectHost,
                    settingsController: settingsController,
                  ),
          )
        else
          FutureBuilder<List<RemoteDockerStatus>>(
            future: remoteStatusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return ErrorCard(
                  message: snapshot.error.toString(),
                  onRetry: onScan,
                );
              }
              final statuses = snapshot.data ?? const <RemoteDockerStatus>[];
              final available = statuses.where((s) => s.available).toList();
              if (available.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text('No Docker-ready remote hosts found.'),
                );
              }
              return RemoteHostList(
                hosts: available,
                onOpenHost: onOpenHost,
                selectedHostName: selectedHostName,
                onSelectHost: onSelectHost,
                settingsController: settingsController,
              );
            },
          ),
      ],
    );
  }
}

class RemoteHostList extends StatelessWidget {
  const RemoteHostList({
    super.key,
    required this.hosts,
    required this.onOpenHost,
    required this.selectedHostName,
    required this.onSelectHost,
    required this.settingsController,
  });

  final List<RemoteDockerStatus> hosts;
  final void Function(SshHost host, Offset? anchor) onOpenHost;
  final String? selectedHostName;
  final void Function(SshHost host, Offset? anchor) onSelectHost;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = _leadingIconSize(context);
    return SectionList(
      children: List.generate(hosts.length, (index) {
        final status = hosts[index];
        final statusColor = status.available ? scheme.primary : scheme.error;
        final isSelected = selectedHostName == status.host.name;
        final slug = settingsController
            .settings
            .serverDistroMap[hostDistroCacheKey(status.host)];
        final iconColor = colorForDistro(slug, context.appTheme);
        Offset? lastPointer;
        return SelectableListItem(
          stripeIndex: index,
          selected: isSelected,
          title: status.host.name,
          subtitle: status.detail,
          onTapDown: (details) => lastPointer = details.globalPosition,
          onTap: () => onSelectHost(status.host, null),
          onDoubleTap: () => onOpenHost(status.host, lastPointer),
          onLongPress: () => onOpenHost(status.host, lastPointer),
          onSecondaryTapDown: (details) =>
              onOpenHost(status.host, details.globalPosition),
          leading: Tooltip(
            message: labelForDistro(slug),
            child: DistroLeadingSlot(
              slug: slug,
              iconSize: iconSize,
              iconColor: iconColor,
              statusColor: statusColor,
              statusDotScale: 10 / iconSize,
            ),
          ),
        );
      }),
    );
  }
}

class EngineButton extends StatelessWidget {
  const EngineButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onDoubleTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.1)
        : scheme.surfaceContainerHighest;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? scheme.primary : null,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons.dns, size: 64),
          const SizedBox(height: 12),
          const Text('No Docker contexts found.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:cwatch/models/docker_context.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/modules/servers/services/host_distro_key.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/distro_icons.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/shared/widgets/distro_leading_slot.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
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
  bool _localCollapsed = false;
  bool _remoteCollapsed = false;

  void _toggleLocalCollapsed() {
    setState(() {
      _localCollapsed = !_localCollapsed;
    });
  }

  void _toggleRemoteCollapsed() {
    setState(() {
      _remoteCollapsed = !_remoteCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final remoteSectionColor = _sectionBackgroundForIndex(context, 1);
    return ListView(
      padding: EdgeInsets.symmetric(vertical: spacing.base),
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
            final collapsed = _localCollapsed;
            final sectionColor = _sectionBackgroundForIndex(context, 0);
            return SectionList(
              title: 'Local contexts',
              backgroundColor: sectionColor,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      collapsed ? Icons.expand_more : Icons.expand_less,
                      size: 18,
                    ),
                    tooltip: collapsed ? 'Expand' : 'Collapse',
                    onPressed: _toggleLocalCollapsed,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Section options',
                    icon: const Icon(Icons.more_horiz, size: 18),
                    onSelected: (value) {
                      if (value == 'reloadContexts') {
                        widget.onRefreshContexts();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'reloadContexts',
                        child: Text('Reload contexts'),
                      ),
                    ],
                  ),
                ],
              ),
              children: collapsed
                  ? const []
                  : [
                      StructuredDataTable<DockerContext>(
                        rows: contexts,
                        columns: _contextColumns(context),
                        rowHeight: 64,
                        shrinkToContent: true,
                        useZebraStripes: false,
                        surfaceBackgroundColor: sectionColor,
                        primaryDoubleClickOpensContextMenu: true,
                        metadataBuilder: _contextMetadata,
                        onRowContextMenu: (ctx, anchor) =>
                            widget.onOpenContext(ctx.name, anchor),
                      ),
                    ],
            );
          },
        ),
        SizedBox(height: spacing.base * 1.5),
        RemoteSection(
          remoteStatusFuture: widget.remoteStatusFuture,
          scanRequested: widget.remoteScanRequested,
          cachedReady: widget.cachedReady,
          onScan: widget.onScanRemotes,
          onOpenHost: widget.onOpenHost,
          settingsController: widget.settingsController,
          collapsed: _remoteCollapsed,
          onToggleCollapsed: _toggleRemoteCollapsed,
          backgroundColor: remoteSectionColor,
        ),
      ],
    );
  }

  Color _sectionBackgroundForIndex(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final base = context.appTheme.section.surface.background;
    final overlay = scheme.surfaceTint.withValues(alpha: 0.08);
    final alternate = Color.alphaBlend(overlay, base);
    return index.isEven ? base : alternate;
  }

  List<StructuredDataColumn<DockerContext>> _contextColumns(
    BuildContext context,
  ) {
    final iconSize = _leadingIconSize(context);
    final icons = context.appTheme.icons;
    return [
      StructuredDataColumn<DockerContext>(
        label: 'Context',
        autoFitText: (ctx) => ctx.name,
        cellBuilder: (context, ctx) => Row(
          children: [
            Icon(
              icons.container,
              size: iconSize,
              color: Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ctx.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      StructuredDataColumn<DockerContext>(
        label: 'Endpoint',
        autoFitText: (ctx) => ctx.dockerEndpoint,
        cellBuilder: (context, ctx) => Text(ctx.dockerEndpoint),
      ),
    ];
  }

  List<StructuredDataChip> _contextMetadata(DockerContext dockerContext) {
    final chips = <StructuredDataChip>[];
    if (dockerContext.current) {
      chips.add(
        const StructuredDataChip(label: 'Current', icon: Icons.check_circle),
      );
    }
    final orchestrator = dockerContext.orchestrator?.trim();
    if (orchestrator != null && orchestrator.isNotEmpty) {
      chips.add(StructuredDataChip(label: orchestrator));
    }
    return chips;
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
    required this.settingsController,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.backgroundColor,
  });

  final Future<List<RemoteDockerStatus>>? remoteStatusFuture;
  final bool scanRequested;
  final List<RemoteDockerStatus> cachedReady;
  final VoidCallback onScan;
  final void Function(SshHost host, Offset? anchor) onOpenHost;
  final AppSettingsController settingsController;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!scanRequested) {
      body = cachedReady.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text('Scan to check which servers have Docker available.'),
            )
          : RemoteHostList(
              hosts: cachedReady,
              onOpenHost: onOpenHost,
              settingsController: settingsController,
              backgroundColor: backgroundColor,
            );
    } else {
      body = FutureBuilder<List<RemoteDockerStatus>>(
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
            settingsController: settingsController,
            backgroundColor: backgroundColor,
          );
        },
      );
    }
    return SectionList(
      title: 'Servers',
      backgroundColor: backgroundColor,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 18,
            ),
            tooltip: collapsed ? 'Expand' : 'Collapse',
            onPressed: onToggleCollapsed,
          ),
          PopupMenuButton<String>(
            tooltip: 'Section options',
            icon: const Icon(Icons.more_horiz, size: 18),
            onSelected: (value) {
              if (value == 'scanServers') {
                onScan();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'scanServers',
                child: Text('Scan servers'),
              ),
            ],
          ),
        ],
      ),
      children: collapsed ? const [] : [body],
    );
  }
}

class RemoteHostList extends StatelessWidget {
  const RemoteHostList({
    super.key,
    required this.hosts,
    required this.onOpenHost,
    required this.settingsController,
    required this.backgroundColor,
  });

  final List<RemoteDockerStatus> hosts;
  final void Function(SshHost host, Offset? anchor) onOpenHost;
  final AppSettingsController settingsController;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return StructuredDataTable<RemoteDockerStatus>(
      rows: hosts,
      columns: _columns(context),
      rowHeight: 64,
      shrinkToContent: true,
      useZebraStripes: false,
      surfaceBackgroundColor: backgroundColor,
      primaryDoubleClickOpensContextMenu: true,
      refreshListenable: settingsController,
      onRowContextMenu: (status, anchor) => onOpenHost(status.host, anchor),
      emptyState: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No Docker-ready remote hosts found.'),
      ),
    );
  }

  List<StructuredDataColumn<RemoteDockerStatus>> _columns(
    BuildContext context,
  ) {
    return [
      StructuredDataColumn<RemoteDockerStatus>(
        label: 'Host',
        autoFitText: (status) => '${status.host.name} ${_hostAddress(status.host)}',
        cellBuilder: (context, status) => _buildCombinedCell(context, status),
      ),
      StructuredDataColumn<RemoteDockerStatus>(
        label: 'Status',
        autoFitText: (status) => status.detail,
        cellBuilder: (context, status) => Text(status.detail),
      ),
    ];
  }

  Widget _buildCombinedCell(BuildContext context, RemoteDockerStatus status) {
    final host = status.host;
    final address = _hostAddress(host);
    final scheme = Theme.of(context).colorScheme;
    final iconSize = _leadingIconSize(context);
    final statusColor = status.available ? scheme.primary : scheme.error;
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        final slug = _slugForHost(host);
        final iconColor = colorForDistro(slug, context.appTheme);
        return ClipRect(
          child: Row(
            children: [
              Tooltip(
                message: labelForDistro(slug),
                child: DistroLeadingSlot(
                  slug: slug,
                  iconSize: iconSize,
                  iconColor: iconColor,
                  statusColor: statusColor,
                  statusDotScale: 10 / iconSize,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      host.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      address,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _hostAddress(SshHost host) {
    final port = host.port;
    final base = host.hostname;
    if (port == 22) {
      return base;
    }
    return '$base:$port';
  }

  String? _slugForHost(SshHost host) {
    return settingsController.settings.serverDistroMap[hostDistroCacheKey(
      host,
    )];
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
    final spacing = context.appTheme.spacing;
    final icons = context.appTheme.icons;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons.dns, size: 64),
          SizedBox(height: spacing.lg),
          const Text('No Docker contexts found.'),
          SizedBox(height: spacing.lg),
          FilledButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

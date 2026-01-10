import 'package:flutter/material.dart';

import 'package:cwatch/model/models/docker_context.dart';
import '../local_docker_context_status.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/distro_icons.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/view/shared/widgets/distro_leading_slot.dart';
import 'package:cwatch/view/shared/widgets/lists/section_list.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'docker_shared.dart';
import '../remote_docker_status.dart';

class EnginePicker extends StatefulWidget {
  const EnginePicker({
    super.key,
    required this.tabId,
    required this.contextsFuture,
    this.contextsStatusFuture,
    required this.cachedReady,
    this.cachedReadyNotifier,
    required this.remoteStatusFuture,
    required this.remoteScanRequested,
    required this.onRefreshContexts,
    required this.onScanRemotes,
    required this.onOpenContext,
    required this.onOpenHost,
    required this.settingsController,
    this.dockerService,
    this.shellFactory,
  });

  final String tabId;
  final Future<List<DockerContext>>? contextsFuture;
  final Future<List<LocalDockerContextStatus>>? contextsStatusFuture;
  final List<RemoteDockerStatus> cachedReady;
  final ValueNotifier<List<RemoteDockerStatus>>? cachedReadyNotifier;
  final Future<List<RemoteDockerStatus>>? remoteStatusFuture;
  final bool remoteScanRequested;
  final VoidCallback onRefreshContexts;
  final VoidCallback onScanRemotes;
  final void Function(String contextName, Offset? anchor) onOpenContext;
  final void Function(SshHost host, Offset? anchor) onOpenHost;
  final AppSettingsController settingsController;
  final DockerClientService? dockerService;
  final SshShellFactory? shellFactory;

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
              return Padding(
                padding: EdgeInsets.all(spacing.xl),
                child: const Center(child: CircularProgressIndicator()),
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
                      FutureBuilder<List<LocalDockerContextStatus>>(
                        future: widget.contextsStatusFuture,
                        builder: (context, statusSnapshot) {
                          // Show contexts immediately, readiness will update when available
                          final statuses = statusSnapshot.data;
                          final rows = statuses ??
                              contexts
                                  .map((ctx) => LocalDockerContextStatus(
                                        context: ctx,
                                        available: false,
                                        detail: 'Checking...',
                                      ))
                                  .toList();
                          return StructuredDataTable<LocalDockerContextStatus>(
                            rows: rows,
                            columns: _contextColumns(context),
                            rowHeight: 64,
                            shrinkToContent: true,
                            useZebraStripes: false,
                            surfaceBackgroundColor: sectionColor,
                            primaryDoubleClickOpensContextMenu: true,
                            metadataBuilder: _contextMetadata,
                            onRowContextMenu: (status, anchor) {
                              // Disable context menu for unavailable contexts
                              if (status.available) {
                                widget.onOpenContext(status.context.name, anchor);
                              }
                            },
                            onRowTap: (status) {
                              // Disable tap for unavailable contexts
                              if (!status.available) {
                                return; // Don't allow interaction with unavailable contexts
                              }
                            },
                            rowSelectionPredicate: (status) => status.available,
                          );
                        },
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
          cachedReadyNotifier: widget.cachedReadyNotifier,
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

  List<StructuredDataColumn<LocalDockerContextStatus>> _contextColumns(
    BuildContext context,
  ) {
    final iconSize = _leadingIconSize(context);
    final icons = context.appTheme.icons;
    final colorScheme = Theme.of(context).colorScheme;
    final opacity = 0.5; // Opacity for disabled contexts
    return [
      StructuredDataColumn<LocalDockerContextStatus>(
        label: 'Context',
        autoFitText: (status) =>
            '${status.context.name} ${status.context.dockerEndpoint}',
        cellBuilder: (context, status) => Opacity(
          opacity: status.available ? 1.0 : opacity,
          child: Row(
            children: [
              Icon(
                icons.container,
                size: iconSize,
                color: Theme.of(context).iconTheme.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status.context.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      status.context.dockerEndpoint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      StructuredDataColumn<LocalDockerContextStatus>(
        label: 'Status',
        autoFitText: (status) => status.detail ?? '',
        cellBuilder: (context, status) => Row(
          children: [
            Icon(
              status.available
                  ? Icons.check_circle
                  : Icons.error_outline,
              size: 16,
              color: status.available
                  ? colorScheme.primary
                  : colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status.detail ?? '',
                style: TextStyle(
                  color: status.available
                      ? colorScheme.primary
                      : colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }


  List<StructuredDataChip> _contextMetadata(
    LocalDockerContextStatus status,
  ) {
    final chips = <StructuredDataChip>[];
    final dockerContext = status.context;
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
    this.cachedReadyNotifier,
    required this.onScan,
    required this.onOpenHost,
    required this.settingsController,
    this.dockerService,
    this.shellFactory,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.backgroundColor,
  });

  final Future<List<RemoteDockerStatus>>? remoteStatusFuture;
  final bool scanRequested;
  final List<RemoteDockerStatus> cachedReady;
  final ValueNotifier<List<RemoteDockerStatus>>? cachedReadyNotifier;
  final VoidCallback onScan;
  final void Function(SshHost host, Offset? anchor) onOpenHost;
  final AppSettingsController settingsController;
  final DockerClientService? dockerService;
  final SshShellFactory? shellFactory;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    Widget body;
    if (!scanRequested) {
      // Use ValueListenableBuilder to hot reload when notifier updates
      final notifier = cachedReadyNotifier ?? ValueNotifier(cachedReady);
      body = ValueListenableBuilder<List<RemoteDockerStatus>>(
        valueListenable: notifier,
        builder: (context, hosts, _) {
          if (hosts.isEmpty) {
            return Padding(
              padding: spacing.inset(horizontal: 1, vertical: 2),
              child: const Text(
                'Scan to check which servers have Docker available.',
              ),
            );
          }
              return RemoteHostList(
                hosts: hosts,
                onOpenHost: onOpenHost,
                settingsController: settingsController,
                dockerService: dockerService,
                backgroundColor: backgroundColor,
              );
        },
      );
    } else {
      // Use ValueListenableBuilder to hot reload when notifier updates
      final notifier = cachedReadyNotifier ?? ValueNotifier(cachedReady);
      body = FutureBuilder<List<RemoteDockerStatus>>(
        future: remoteStatusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: const LinearProgressIndicator(),
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
          // Update notifier when scan completes
          if (snapshot.connectionState == ConnectionState.done) {
            notifier.value = available;
          }
          return ValueListenableBuilder<List<RemoteDockerStatus>>(
            valueListenable: notifier,
            builder: (context, hosts, _) {
              if (hosts.isEmpty) {
                return Padding(
                  padding: spacing.inset(horizontal: 1, vertical: 2),
                  child: const Text('No Docker-ready remote hosts found.'),
                );
              }
              return RemoteHostList(
                hosts: hosts,
                onOpenHost: onOpenHost,
                settingsController: settingsController,
                dockerService: dockerService,
                shellFactory: shellFactory,
                backgroundColor: backgroundColor,
              );
            },
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

class RemoteHostList extends StatefulWidget {
  const RemoteHostList({
    super.key,
    required this.hosts,
    required this.onOpenHost,
    required this.settingsController,
    this.dockerService,
    this.shellFactory,
    required this.backgroundColor,
  });

  final List<RemoteDockerStatus> hosts;
  final void Function(SshHost host, Offset? anchor) onOpenHost;
  final AppSettingsController settingsController;
  final DockerClientService? dockerService;
  final SshShellFactory? shellFactory;
  final Color backgroundColor;

  @override
  State<RemoteHostList> createState() => _RemoteHostListState();
}

class _RemoteHostListState extends State<RemoteHostList> {

  @override
  Widget build(BuildContext context) {
    return StructuredDataTable<RemoteDockerStatus>(
      rows: widget.hosts,
      columns: _columns(context),
      rowHeight: 64,
      shrinkToContent: true,
      useZebraStripes: false,
      surfaceBackgroundColor: widget.backgroundColor,
      primaryDoubleClickOpensContextMenu: true,
      refreshListenable: widget.settingsController,
      onRowContextMenu: (status, anchor) => widget.onOpenHost(status.host, anchor),
      emptyState: Padding(
        padding: EdgeInsets.all(context.appTheme.spacing.xl),
        child: const Text('No Docker-ready remote hosts found.'),
      ),
    );
  }

  List<StructuredDataColumn<RemoteDockerStatus>> _columns(
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      StructuredDataColumn<RemoteDockerStatus>(
        label: 'Host',
        autoFitText: (status) =>
            '${status.host.name} ${_hostAddress(status.host)}',
        cellBuilder: (context, status) => _buildCombinedCell(context, status),
      ),
      StructuredDataColumn<RemoteDockerStatus>(
        label: 'Status',
        autoFitText: (status) => status.detail,
        cellBuilder: (context, status) => Row(
          children: [
            Icon(
              status.available
                  ? Icons.check_circle
                  : Icons.error_outline,
              size: 16,
              color: status.available
                  ? colorScheme.primary
                  : colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status.detail,
                style: TextStyle(
                  color: status.available
                      ? colorScheme.primary
                      : colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildCombinedCell(BuildContext context, RemoteDockerStatus status) {
    final host = status.host;
    final address = _hostAddress(host);
    final iconSize = _leadingIconSize(context);
    return AnimatedBuilder(
      animation: widget.settingsController,
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
                  statusColor: Colors.transparent,
                  statusDotScale: 0,
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.0),
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
    return widget.settingsController.settings.serverDistroMap[hostDistroCacheKey(
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
    final spacing = context.appTheme.spacing;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.1)
        : scheme.surfaceContainerHighest;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: 200,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.base * 3,
            vertical: spacing.base * 2.5,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(2),
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

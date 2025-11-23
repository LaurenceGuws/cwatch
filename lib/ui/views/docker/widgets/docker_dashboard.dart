import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/docker_container.dart';
import '../../../../models/docker_image.dart';
import '../../../../models/docker_network.dart';
import '../../../../models/docker_volume.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/docker/docker_client_service.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../theme/nerd_fonts.dart';
import '../../shared/engine_tab.dart';
import 'docker_command_terminal.dart';
import 'docker_lists.dart';
import 'docker_shared.dart';
import 'section_card.dart';

typedef OpenTab = void Function(EngineTab tab);

class DockerDashboard extends StatefulWidget {
  const DockerDashboard({
    super.key,
    required this.docker,
    this.contextName,
    this.remoteHost,
    this.shellService,
    this.onOpenTab,
  });

  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;
  final OpenTab? onOpenTab;

  @override
  State<DockerDashboard> createState() => _DockerDashboardState();
}

class _DockerDashboardState extends State<DockerDashboard> {
  Future<EngineSnapshot>? _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<EngineSnapshot> _load() async {
    if (widget.contextName != null && widget.contextName!.isNotEmpty) {
      final containers = await widget.docker.listContainers(
        context: widget.contextName,
        dockerHost: null,
      );
      final images = await widget.docker.listImages(
        context: widget.contextName,
      );
      final networks = await widget.docker.listNetworks(
        context: widget.contextName,
      );
      final volumes = await widget.docker.listVolumes(
        context: widget.contextName,
      );
      return EngineSnapshot(
        containers: containers,
        images: images,
        networks: networks,
        volumes: volumes,
      );
    }

    if (widget.remoteHost != null && widget.shellService != null) {
      final containers = await _loadRemoteContainers(
        widget.shellService!,
        widget.remoteHost!,
      );
      final images = await _loadRemoteImages(
        widget.shellService!,
        widget.remoteHost!,
      );
      final networks = await _loadRemoteNetworks(
        widget.shellService!,
        widget.remoteHost!,
      );
      final volumes = await _loadRemoteVolumes(
        widget.shellService!,
        widget.remoteHost!,
      );
      return EngineSnapshot(
        containers: containers,
        images: images,
        networks: networks,
        volumes: volumes,
      );
    }

    final containers = await widget.docker.listContainers();
    final images = await widget.docker.listImages();
    final networks = await widget.docker.listNetworks();
    final volumes = await widget.docker.listVolumes();
    return EngineSnapshot(
      containers: containers,
      images: images,
      networks: networks,
      volumes: volumes,
    );
  }

  Future<List<DockerContainer>> _loadRemoteContainers(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker ps -a --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    return _parseContainers(output);
  }

  Future<List<DockerImage>> _loadRemoteImages(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker images --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    return _parseImages(output);
  }

  Future<List<DockerNetwork>> _loadRemoteNetworks(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker network ls --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    return _parseNetworks(output);
  }

  Future<List<DockerVolume>> _loadRemoteVolumes(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker volume ls --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    return _parseVolumes(output);
  }

  List<DockerContainer> _parseContainers(String output) {
    final items = <DockerContainer>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final labelsRaw = (decoded['Labels'] as String?)?.trim() ?? '';
          final labels = _parseLabels(labelsRaw);
          items.add(
            DockerContainer(
              id: (decoded['ID'] as String?)?.trim() ?? '',
              name: (decoded['Names'] as String?)?.trim() ?? '',
              image: (decoded['Image'] as String?)?.trim() ?? '',
              state: (decoded['State'] as String?)?.trim() ?? '',
              status: (decoded['Status'] as String?)?.trim() ?? '',
              ports: (decoded['Ports'] as String?)?.trim() ?? '',
              command: (decoded['Command'] as String?)?.trim(),
              createdAt: (decoded['RunningFor'] as String?)?.trim(),
              composeProject: labels['com.docker.compose.project'],
              composeService: labels['com.docker.compose.service'],
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  Map<String, String> _parseLabels(String labelsRaw) {
    if (labelsRaw.isEmpty) return const {};
    final entries = <String, String>{};
    for (final part in labelsRaw.split(',')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        entries[kv[0].trim()] = kv[1].trim();
      }
    }
    return entries;
  }

  List<DockerImage> _parseImages(String output) {
    final items = <DockerImage>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          items.add(
            DockerImage(
              id: (decoded['ID'] as String?)?.trim() ?? '',
              repository: (decoded['Repository'] as String?)?.trim() ?? '',
              tag: (decoded['Tag'] as String?)?.trim() ?? '',
              size: (decoded['Size'] as String?)?.trim() ?? '',
              createdSince: (decoded['CreatedSince'] as String?)?.trim() ?? '',
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  List<DockerNetwork> _parseNetworks(String output) {
    final items = <DockerNetwork>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          items.add(
            DockerNetwork(
              id: (decoded['ID'] as String?)?.trim() ?? '',
              name: (decoded['Name'] as String?)?.trim() ?? '',
              driver: (decoded['Driver'] as String?)?.trim() ?? '',
              scope: (decoded['Scope'] as String?)?.trim() ?? '',
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  List<DockerVolume> _parseVolumes(String output) {
    final items = <DockerVolume>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          items.add(
            DockerVolume(
              name: (decoded['Name'] as String?)?.trim() ?? '',
              driver: (decoded['Driver'] as String?)?.trim() ?? '',
              mountpoint: (decoded['Mountpoint'] as String?)?.trim(),
              scope: (decoded['Scope'] as String?)?.trim(),
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  void _refresh() {
    setState(() {
      _snapshot = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.contextName ?? widget.remoteHost?.name ?? 'Dashboard';
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<EngineSnapshot>(
              future: _snapshot,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorCard(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: Text('No data.'));
                }
                final containers = data.containers;
                final images = data.images;
                final networks = data.networks;
                final volumes = data.volumes;
                final running = containers.where((c) => c.isRunning).length;
                final stopped = containers.length - running;
                final total = containers.length;
                final statsCards = [
                  StatCard(
                    label: 'Containers',
                    value: total.toString(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  StatCard(
                    label: 'Running',
                    value: running.toString(),
                    color: Colors.green,
                  ),
                  StatCard(
                    label: 'Stopped',
                    value: stopped.toString(),
                    color: Colors.orange,
                  ),
                  StatCard(
                    label: 'Images',
                    value: images.length.toString(),
                    color: Colors.blueGrey,
                  ),
                  StatCard(
                    label: 'Networks',
                    value: networks.length.toString(),
                    color: Colors.teal,
                  ),
                  StatCard(
                    label: 'Volumes',
                    value: volumes.length.toString(),
                    color: Colors.deepPurple,
                  ),
                ];

                if (containers.isEmpty &&
                    images.isEmpty &&
                    networks.isEmpty &&
                    volumes.isEmpty) {
                  return const Center(
                    child: Text(
                      'No containers, images, networks, or volumes found.',
                    ),
                  );
                }
                return ListView(
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: statsCards),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'Containers',
                      child: ContainerPeek(
                        containers: containers,
                        onTapDown: _openContainerMenu,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Images',
                      child: ImagePeek(
                        images: images,
                        onTapDown: _openImageMenu,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Networks',
                      child: NetworkList(
                        networks: networks,
                        onTapDown: _openNetworkMenu,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Volumes',
                      child: VolumeList(
                        volumes: volumes,
                        onTapDown: _openVolumeMenu,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openContainerMenu(DockerContainer container, TapDownDetails details) {
    _showItemMenu(
      globalPosition: details.globalPosition,
      title: container.name.isNotEmpty ? container.name : container.id,
      details: {
        'Image': container.image,
        'Status': container.status,
        'Ports': container.ports,
      },
      copyValue: container.id,
      copyLabel: 'Container ID',
      extraActions: const [
        PopupMenuItem(value: 'logs', child: Text('Tail logs (last 200)')),
        PopupMenuItem(value: 'shell', child: Text('Open shell tab')),
        PopupMenuItem(
          value: 'copyExec',
          child: Text('Copy exec shell command'),
        ),
      ],
      onAction: (action) async {
        if (action == 'logs') {
          await _showLogs(container);
        } else if (action == 'shell') {
          await _openExecTerminal(container);
        } else if (action == 'copyExec') {
          await _copyExecCommand(container.id);
        }
      },
    );
  }

  void _openImageMenu(DockerImage image, TapDownDetails details) {
    final ref = [
      image.repository.isNotEmpty ? image.repository : '<none>',
      image.tag.isNotEmpty ? image.tag : '<none>',
    ].join(':');
    _showItemMenu(
      globalPosition: details.globalPosition,
      title: ref,
      details: {'ID': image.id, 'Size': image.size},
      copyValue: image.id,
      copyLabel: 'Image ID',
    );
  }

  void _openNetworkMenu(DockerNetwork network, TapDownDetails details) {
    _showItemMenu(
      globalPosition: details.globalPosition,
      title: network.name,
      details: {'Driver': network.driver, 'Scope': network.scope},
      copyValue: network.id,
      copyLabel: 'Network ID',
    );
  }

  void _openVolumeMenu(DockerVolume volume, TapDownDetails details) {
    _showItemMenu(
      globalPosition: details.globalPosition,
      title: volume.name,
      details: {
        'Driver': volume.driver,
        'Mountpoint': volume.mountpoint ?? '—',
        'Scope': volume.scope ?? '—',
      },
      copyValue: volume.name,
      copyLabel: 'Volume name',
    );
  }

  Future<void> _showItemMenu({
    required Offset globalPosition,
    required String title,
    required Map<String, String> details,
    required String copyValue,
    required String copyLabel,
    List<PopupMenuEntry<String>> extraActions = const [],
    Future<void> Function(String action)? onAction,
  }) async {
    if (!mounted) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        PopupMenuItem(value: 'copy', child: Text('Copy $copyLabel')),
        const PopupMenuItem(value: 'details', child: Text('Details')),
        ...extraActions,
      ],
    );

    if (selected == 'copy') {
      await _copyToClipboard(copyValue, copyLabel);
    } else if (selected == 'details') {
      await _showDetailsDialog(title: title, details: details);
    } else if (selected != null && onAction != null) {
      await onAction(selected);
    }
  }

  Future<void> _showDetailsDialog({
    required String title,
    required Map<String, String> details,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(child: Text(entry.value)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard.')));
  }

  Future<void> _showLogs(DockerContainer container) async {
    if (!mounted) return;
    try {
      final logs = await _loadLogs(container.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Logs: ${container.name.isNotEmpty ? container.name : container.id}',
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: SelectableText(
                  logs.isNotEmpty ? logs : 'No logs available.',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Failed to load logs'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<String> _loadLogs(String containerId) async {
    if (widget.remoteHost != null && widget.shellService != null) {
      return widget.shellService!.runCommand(
        widget.remoteHost!,
        'docker logs --tail 200 $containerId',
        timeout: const Duration(seconds: 8),
      );
    }

    final args = <String>[
      if (widget.contextName != null && widget.contextName!.isNotEmpty) ...[
        '--context',
        widget.contextName!,
      ],
      'logs',
      '--tail',
      '200',
      containerId,
    ];
    final result = await widget.docker.processRunner(
      'docker',
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker logs failed with exit code ${result.exitCode}',
      );
    }
    return (result.stdout as String?) ?? '';
  }

  Future<void> _copyExecCommand(String containerId) async {
    final contextFlag =
        widget.contextName != null && widget.contextName!.isNotEmpty
        ? '--context ${widget.contextName!} '
        : '';
    final command =
        'docker ${contextFlag}exec -it $containerId /bin/sh # change to /bin/bash if needed';
    await _copyToClipboard(command, 'Exec command');
  }

  Future<void> _openExecTerminal(DockerContainer container) async {
    if (widget.remoteHost == null || widget.shellService == null) {
      final name = container.name.isNotEmpty ? container.name : container.id;
      final command = 'docker exec -it ${container.id} /bin/sh';
      if (widget.onOpenTab != null) {
        final tab = EngineTab(
          id: 'exec-${container.id}-${DateTime.now().microsecondsSinceEpoch}',
          title: 'Shell: $name',
          label: 'Shell: $name',
          icon: NerdIcon.terminal.data,
          body: DockerCommandTerminal(
            host: null,
            shellService: null,
            command: command,
            title: 'Exec shell • $name',
          ),
          canDrag: true,
        );
        widget.onOpenTab!(tab);
      } else {
        await _copyExecCommand(container.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No remote host available. Exec command copied.'),
          ),
        );
      }
      return;
    }
    final name = container.name.isNotEmpty ? container.name : container.id;
    final command = 'docker exec -it ${container.id} /bin/sh';
    if (widget.onOpenTab != null) {
      final tab = EngineTab(
        id: 'exec-${container.id}-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Shell: $name',
        label: 'Shell: $name',
        icon: NerdIcon.terminal.data,
        body: DockerCommandTerminal(
          host: widget.remoteHost!,
          shellService: widget.shellService!,
          command: command,
          title: 'Exec shell • $name',
        ),
        canDrag: true,
      );
      widget.onOpenTab!(tab);
    } else {
      await _copyExecCommand(container.id);
    }
  }
}

class EngineSnapshot {
  const EngineSnapshot({
    required this.containers,
    required this.images,
    required this.networks,
    required this.volumes,
  });

  final List<DockerContainer> containers;
  final List<DockerImage> images;
  final List<DockerNetwork> networks;
  final List<DockerVolume> volumes;
}

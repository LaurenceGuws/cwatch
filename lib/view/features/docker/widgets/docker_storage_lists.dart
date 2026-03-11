import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/view/shared/widgets/lists/section_list.dart';

import 'docker_grouped_section_state_controller.dart';
import 'docker_lists.dart' show EmptyCard, ItemTapDown;
import 'docker_lists_helpers.dart';

class NetworkList extends StatefulWidget {
  const NetworkList({
    super.key,
    required this.networks,
    this.onTap,
    this.onTapDown,
    this.onSelectionChanged,
    required this.selectedIds,
  });

  final List<DockerNetwork> networks;
  final ValueChanged<DockerNetwork>? onTap;
  final ItemTapDown<DockerNetwork>? onTapDown;
  final void Function(Set<String> tableKeys, List<DockerNetwork> selected)?
  onSelectionChanged;
  final Set<String> selectedIds;

  @override
  State<NetworkList> createState() => _NetworkListState();
}

class _NetworkListState extends State<NetworkList> {
  final DockerGroupedSectionStateController<DockerNetwork> _stateController =
      DockerGroupedSectionStateController<DockerNetwork>();

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    if (widget.networks.isEmpty) {
      return const EmptyCard(message: 'No networks found.');
    }
    final spacing = context.appTheme.spacing;
    final sections = _stateController.buildSections(
      widget.networks,
      (network) => inferComposeGroup(network.name),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(sections.length, (index) {
        final section = sections[index];
        final group = section.group;
        final items = section.items;
        final collapsed = section.collapsed;
        final sectionColor = sectionBackgroundForIndex(context, index);
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          child: SectionList(
            title: group,
            backgroundColor: sectionColor,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.countLabel('network'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    setState(() {
                      _stateController.toggle(group);
                    });
                  },
                ),
              ],
            ),
            children: collapsed
                ? const []
                : [
                    StructuredDataTable<DockerNetwork>(
                      rows: items,
                      columns: _networkColumns(context, icons),
                      rowHeight: 64,
                      shrinkToContent: true,
                      useZebraStripes: false,
                      surfaceBackgroundColor: sectionColor,
                      primaryDoubleClickOpensContextMenu: false,
                      onRowContextMenu: _handleNetworkContextMenu,
                      onSelectionChanged: (selectedRows) {
                        final keys = items
                            .map(
                              (item) =>
                                  item.id.isNotEmpty ? item.id : item.name,
                            )
                            .toSet();
                        widget.onSelectionChanged?.call(keys, selectedRows);
                      },
                    ),
                  ],
          ),
        );
      }),
    );
  }

  void _handleNetworkContextMenu(
    DockerNetwork network,
    List<DockerNetwork> selectedRows,
    Offset? anchor,
  ) {
    if (widget.onTapDown == null) {
      return;
    }
    widget.onTapDown!(
      network,
      _tapDetails(anchor: anchor),
      secondary: true,
      selectedRows: selectedRows,
    );
  }

  List<StructuredDataColumn<DockerNetwork>> _networkColumns(
    BuildContext context,
    AppIcons icons,
  ) {
    return [
      StructuredDataColumn<DockerNetwork>(
        label: 'Network',
        autoFitText: (network) => network.name,
        cellBuilder: (context, network) => Row(
          children: [
            Icon(
              icons.network,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                network.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      StructuredDataColumn<DockerNetwork>(
        label: 'Driver',
        autoFitText: (network) => network.driver,
        cellBuilder: (context, network) => Text(network.driver),
      ),
      StructuredDataColumn<DockerNetwork>(
        label: 'Scope',
        autoFitText: (network) => network.scope,
        cellBuilder: (context, network) => Text(network.scope),
      ),
    ];
  }
}

class VolumeList extends StatefulWidget {
  const VolumeList({
    super.key,
    required this.volumes,
    this.onTap,
    this.onTapDown,
    this.onSelectionChanged,
    required this.selectedIds,
  });

  final List<DockerVolume> volumes;
  final ValueChanged<DockerVolume>? onTap;
  final ItemTapDown<DockerVolume>? onTapDown;
  final void Function(Set<String> tableKeys, List<DockerVolume> selected)?
  onSelectionChanged;
  final Set<String> selectedIds;

  @override
  State<VolumeList> createState() => _VolumeListState();
}

class _VolumeListState extends State<VolumeList> {
  final DockerGroupedSectionStateController<DockerVolume> _stateController =
      DockerGroupedSectionStateController<DockerVolume>();

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    if (widget.volumes.isEmpty) {
      return const EmptyCard(message: 'No volumes found.');
    }
    final spacing = context.appTheme.spacing;
    final sections = _stateController.buildSections(
      widget.volumes,
      (volume) => inferComposeGroup(volume.name),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(sections.length, (index) {
        final section = sections[index];
        final group = section.group;
        final items = section.items;
        final collapsed = section.collapsed;
        final sectionColor = sectionBackgroundForIndex(context, index);
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          child: SectionList(
            title: group,
            backgroundColor: sectionColor,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.countLabel('volume'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    setState(() {
                      _stateController.toggle(group);
                    });
                  },
                ),
              ],
            ),
            children: collapsed
                ? const []
                : [
                    StructuredDataTable<DockerVolume>(
                      rows: items,
                      columns: _volumeColumns(context, icons),
                      rowHeight: 64,
                      shrinkToContent: true,
                      useZebraStripes: false,
                      surfaceBackgroundColor: sectionColor,
                      primaryDoubleClickOpensContextMenu: false,
                      onRowContextMenu: _handleVolumeContextMenu,
                      onSelectionChanged: (selectedRows) {
                        final keys = items.map((item) => item.name).toSet();
                        widget.onSelectionChanged?.call(keys, selectedRows);
                      },
                    ),
                  ],
          ),
        );
      }),
    );
  }

  void _handleVolumeContextMenu(
    DockerVolume volume,
    List<DockerVolume> selectedRows,
    Offset? anchor,
  ) {
    if (widget.onTapDown == null) {
      return;
    }
    widget.onTapDown!(
      volume,
      _tapDetails(anchor: anchor),
      secondary: true,
      selectedRows: selectedRows,
    );
  }

  List<StructuredDataColumn<DockerVolume>> _volumeColumns(
    BuildContext context,
    AppIcons icons,
  ) {
    return [
      StructuredDataColumn<DockerVolume>(
        label: 'Volume',
        autoFitText: (volume) => volume.name,
        cellBuilder: (context, volume) => Row(
          children: [
            Icon(
              icons.volume,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                volume.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      StructuredDataColumn<DockerVolume>(
        label: 'Driver',
        autoFitText: (volume) => volume.driver,
        cellBuilder: (context, volume) => Text(volume.driver),
      ),
      StructuredDataColumn<DockerVolume>(
        label: 'Size',
        alignment: Alignment.centerRight,
        autoFitText: (volume) => valueOrDash(volume.size),
        cellBuilder: (context, volume) => Text(valueOrDash(volume.size)),
      ),
      StructuredDataColumn<DockerVolume>(
        label: 'Scope',
        autoFitText: (volume) => valueOrDash(volume.scope),
        cellBuilder: (context, volume) => Text(valueOrDash(volume.scope)),
      ),
    ];
  }
}

TapDownDetails _tapDetails({
  Offset? anchor,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) {
  final position = anchor ?? Offset.zero;
  return TapDownDetails(
    globalPosition: position,
    localPosition: position,
    kind: kind,
  );
}

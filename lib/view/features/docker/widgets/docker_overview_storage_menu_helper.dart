import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_action_state.dart';

class DockerOverviewStorageMenuProjection<T> {
  const DockerOverviewStorageMenuProjection({
    required this.title,
    required this.details,
    required this.copyValue,
    required this.copyLabel,
  });

  final String title;
  final Map<String, String> details;
  final String copyValue;
  final String copyLabel;
}

class DockerOverviewStorageMenuHelper {
  const DockerOverviewStorageMenuHelper();

  DockerOverviewStorageMenuProjection<DockerNetwork> projectNetworkMenu({
    required DockerNetwork network,
    required List<DockerNetwork>? selectedRows,
    required Set<String> selectedKeys,
    required List<DockerNetwork> networks,
    required DockerOverviewActionState actionState,
  }) {
    final selection = selectedRows?.isNotEmpty == true
        ? selectedRows!
        : actionState.selectedNetworksForAction(
            fallback: network,
            selectedKeys: selectedKeys,
            networks: networks,
          );
    final isMulti = selection.length > 1;
    return DockerOverviewStorageMenuProjection(
      title: isMulti ? '${selection.length} networks selected' : network.name,
      details: isMulti
          ? {'Selected': '${selection.length}'}
          : {'Driver': network.driver, 'Scope': network.scope},
      copyValue: isMulti
          ? selection.map(actionState.networkKey).join('\n')
          : actionState.networkKey(network),
      copyLabel: isMulti ? 'Network IDs' : 'Network ID',
    );
  }

  DockerOverviewStorageMenuProjection<DockerVolume> projectVolumeMenu({
    required DockerVolume volume,
    required List<DockerVolume>? selectedRows,
    required Set<String> selectedKeys,
    required List<DockerVolume> volumes,
    required DockerOverviewActionState actionState,
  }) {
    final selection = selectedRows?.isNotEmpty == true
        ? selectedRows!
        : actionState.selectedVolumesForAction(
            fallback: volume,
            selectedKeys: selectedKeys,
            volumes: volumes,
          );
    final isMulti = selection.length > 1;
    return DockerOverviewStorageMenuProjection(
      title: isMulti ? '${selection.length} volumes selected' : volume.name,
      details: isMulti
          ? {'Selected': '${selection.length}'}
          : {
              'Driver': volume.driver,
              'Mountpoint': volume.mountpoint ?? '—',
              'Scope': volume.scope ?? '—',
            },
      copyValue: isMulti
          ? selection.map((item) => item.name).join('\n')
          : volume.name,
      copyLabel: isMulti ? 'Volume names' : 'Volume name',
    );
  }
}

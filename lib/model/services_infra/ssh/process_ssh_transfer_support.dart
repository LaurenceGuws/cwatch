import 'package:cwatch/model/models/ssh_host.dart';

class ProcessSshTransferSupport {
  const ProcessSshTransferSupport();

  List<String> buildScpArgs({
    required Set<String> identityFiles,
    int? remotePort,
    bool recursive = false,
    List<String> extraFlags = const [],
  }) {
    final args = <String>[
      'scp',
      '-o',
      'BatchMode=yes',
      '-o',
      'StrictHostKeyChecking=accept-new',
      ...extraFlags,
    ];
    if (remotePort != null) {
      args.addAll(['-P', remotePort.toString()]);
    }
    if (recursive) {
      args.add('-r');
    }
    for (final identity in identityFiles) {
      final trimmed = identity.trim();
      if (trimmed.isNotEmpty) {
        args.addAll(['-i', trimmed]);
      }
    }
    return args;
  }

  String formatRemoteSpec(SshHost host, String path, {String? connectionTarget}) {
    final normalized = _sanitizePath(path);
    final target = connectionTarget ?? _defaultConnectionTarget(host);
    return '$target:$normalized';
  }

  String? parentDirectory(String directory) {
    if (directory.isEmpty) {
      return null;
    }
    return directory;
  }

  String _defaultConnectionTarget(SshHost host) {
    final user = host.user?.trim();
    final destination = host.hostname.trim();
    if (user != null && user.isNotEmpty) {
      return '$user@$destination';
    }
    return destination;
  }

  String _sanitizePath(String path) {
    if (path.isEmpty) {
      return '/';
    }
    if (path.startsWith('/')) {
      return path;
    }
    return '/$path';
  }
}

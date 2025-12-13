import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_client_manager.dart';
import 'package:cwatch/models/ssh_client_backend.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/process_ssh_runner.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/ssh_auth_coordinator.dart';
import 'package:dartssh2/dartssh2.dart';

class PortForwardRequest {
  PortForwardRequest({
    required this.remoteHost,
    required this.remotePort,
    required this.localPort,
    this.label,
  });

  final String remoteHost;
  int remotePort;
  int localPort;
  final String? label;

  PortForwardRequest copy() => PortForwardRequest(
    remoteHost: remoteHost,
    remotePort: remotePort,
    localPort: localPort,
    label: label,
  );
}

class ActivePortForward {
  ActivePortForward({
    required this.id,
    required this.host,
    required this.requests,
    this.process,
    this.client,
    this.channels,
    this.sockets,
    this.acceptSubscriptions,
    required this.startedAt,
    required this.onExit,
    this.onClose,
  });

  final String id;
  final SshHost host;
  final List<PortForwardRequest> requests;
  final Process? process;
  final SSHClient? client;
  final List<SSHForwardChannel>? channels;
  final List<ServerSocket>? sockets;
  final List<StreamSubscription<Socket>>? acceptSubscriptions;
  final DateTime startedAt;
  final void Function(int code, String stderr) onExit;
  final Future<void> Function()? onClose;

  bool _closed = false;
  int? exitCode;
  String? error;

  bool get isRunning => !_closed && exitCode == null;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (process != null) {
      process!.kill();
      try {
        exitCode = await process!.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process!.kill(ProcessSignal.sigkill);
        exitCode = -9;
      }
    } else {
      for (final sub
          in acceptSubscriptions ?? const <StreamSubscription<Socket>>[]) {
        try {
          await sub.cancel();
        } catch (_) {}
      }
      for (final socket in sockets ?? const <ServerSocket>[]) {
        try {
          await socket.close();
        } catch (_) {}
      }
      for (final channel in channels ?? const <SSHForwardChannel>[]) {
        try {
          await channel.close();
          await channel.done;
        } catch (_) {
          // ignore
        }
      }
      try {
        client?.close();
        await client?.done;
      } catch (_) {
        // ignore
      }
      exitCode ??= 0;
    }
    if (onClose != null) {
      await onClose!();
    }
  }

  void markExited(int code, String stderr) {
    exitCode = code;
    error = stderr.isNotEmpty ? stderr : null;
  }
}

/// Tracks SSH port forward processes and provides helpers for reserving
/// available local ports.
class PortForwardService extends ChangeNotifier {
  PortForwardService({SshAuthCoordinator? authCoordinator})
    : _authCoordinator = authCoordinator {
    _installSignalHandlers();
  }

  final Map<String, ActivePortForward> _forwards = {};
  final ProcessSshRunner _runner = const ProcessSshRunner();
  final List<StreamSubscription<ProcessSignal>> _signalSubscriptions = [];
  AppSettingsController? _settingsController;
  SshAuthCoordinator? _authCoordinator;

  void setAuthCoordinator(SshAuthCoordinator coordinator) {
    _authCoordinator = coordinator;
  }

  List<ActivePortForward> get activeForwards =>
      List.unmodifiable(_forwards.values);
  Iterable<ActivePortForward> forwardsForHost(SshHost host) sync* {
    for (final f in _forwards.values) {
      if (f.host.name == host.name) {
        yield f;
      }
    }
  }

  ActivePortForward? findForward({
    required SshHost host,
    required Set<int> remotePorts,
  }) {
    for (final f in forwardsForHost(host)) {
      final ports = f.requests.map((r) => r.remotePort).toSet();
      if (ports.containsAll(remotePorts)) return f;
    }
    return null;
  }

  Future<bool> isPortAvailable(int port) async {
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await socket.close();
      return true;
    } catch (_) {
      try {
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv6,
          port,
        );
        await socket.close();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<int> suggestLocalPort(int preferred) async {
    var candidate = preferred;
    final used = _forwards.values
        .expand((f) => f.requests.map((r) => r.localPort))
        .toSet();
    while (candidate < 65535) {
      if (!used.contains(candidate) && await isPortAvailable(candidate)) {
        return candidate;
      }
      candidate += 1;
    }
    throw Exception('No free local ports available');
  }

  Future<ServerSocket> _bindLoopback(int port, {bool allowIpv6 = false}) async {
    try {
      return await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    } catch (_) {
      if (!allowIpv6) rethrow;
      return ServerSocket.bind(InternetAddress.loopbackIPv6, port);
    }
  }

  Future<ActivePortForward> startForward({
    required SshHost host,
    required List<PortForwardRequest> requests,
    AppSettingsController? settingsController,
    BuiltInSshKeyService? builtInKeyService,
    Map<String, String> hostKeyBindings = const {},
    Future<bool> Function(String keyId, String hostName, String? keyLabel)?
    promptUnlock,
    Duration builtInConnectTimeout = const Duration(seconds: 10),
    SshAuthCoordinator? authCoordinator,
  }) async {
    _settingsController ??= settingsController;
    final usingBuiltIn =
        _settingsController != null &&
        _settingsController!.settings.sshClientBackend ==
            SshClientBackend.builtin &&
        builtInKeyService != null;
    if (requests.isEmpty) {
      throw Exception('No ports to forward');
    }
    final id = 'pf-${DateTime.now().microsecondsSinceEpoch}';
    if (usingBuiltIn) {
      final manager = BuiltInSshClientManager(
        vault: builtInKeyService.vault,
        hostKeyBindings: hostKeyBindings,
        connectTimeout: builtInConnectTimeout,
        authCoordinator:
            authCoordinator ??
            _authCoordinator ??
            (promptUnlock != null
                ? SshAuthCoordinator().withUnlockFallback(promptUnlock)
                : const SshAuthCoordinator()),
      );
      final client = await manager.openPersistentClient(host);
      final channels = <SSHForwardChannel>[];
      final sockets = <ServerSocket>[];
      final acceptSubscriptions = <StreamSubscription<Socket>>[];
      for (final req in requests) {
        final serverSocket = await _bindLoopback(
          req.localPort,
          allowIpv6: true,
        );
        sockets.add(serverSocket);
        final sub = serverSocket.listen((localSocket) async {
          try {
            final channel = await client.forwardLocal(
              req.remoteHost,
              req.remotePort,
              localHost: localSocket.address.address,
              localPort: localSocket.port,
            );
            channels.add(channel);
            final toLocal = channel.stream.cast<List<int>>().pipe(localSocket);
            final toRemote = localSocket.cast<List<int>>().pipe(channel.sink);
            unawaited(
              toLocal.catchError((_) {}).whenComplete(() {
                try {
                  localSocket.destroy();
                } catch (_) {}
              }),
            );
            unawaited(
              toRemote.catchError((_) {}).whenComplete(() async {
                try {
                  await channel.sink.close();
                } catch (_) {}
              }),
            );
          } catch (error) {
            try {
              localSocket.destroy();
            } catch (_) {}
          }
        });
        acceptSubscriptions.add(sub);
      }

      late ActivePortForward forward;
      forward = ActivePortForward(
        id: id,
        host: host,
        requests: requests.map((r) => r.copy()).toList(),
        client: client,
        channels: channels,
        sockets: sockets,
        acceptSubscriptions: acceptSubscriptions,
        startedAt: DateTime.now(),
        onExit: (code, stderr) {
          forward.markExited(code, stderr);
          _forwards.remove(id);
          notifyListeners();
        },
        onClose: () async {
          for (final sub in acceptSubscriptions) {
            try {
              await sub.cancel();
            } catch (_) {}
          }
          for (final socket in sockets) {
            try {
              await socket.close();
            } catch (_) {}
          }
          try {
            client.close();
            await client.done;
          } catch (_) {
            // ignore
          }
        },
      );

      client.done.then((_) {
        if (_forwards.containsKey(id)) {
          forward.onExit(0, '');
        }
      });

      _forwards[id] = forward;
      notifyListeners();
      return forward;
    }

    final args = <String>[
      'ssh',
      ..._runner.buildBaseSshOptions(host),
      '-N',
      '-o',
      'ExitOnForwardFailure=yes',
    ];
    for (final req in requests) {
      args.addAll([
        '-L',
        '${req.localPort}:${req.remoteHost}:${req.remotePort}',
      ]);
    }
    args.add(_runner.connectionTarget(host));

    final process = await Process.start(
      args.first,
      args.skip(1).toList(),
      runInShell: false,
    );

    final stderrBuffer = StringBuffer();
    // Drain outputs to avoid hanging the process.
    process.stdout.transform(utf8.decoder).listen((_) {});
    process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

    final exitFuture = process.exitCode;
    final initialExit = await exitFuture.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () => -1,
    );
    if (initialExit != -1) {
      final stderr = stderrBuffer.toString().trim();
      process.kill();
      throw Exception(
        stderr.isNotEmpty
            ? stderr
            : 'SSH port forward exited with code $initialExit',
      );
    }

    late ActivePortForward forward;
    forward = ActivePortForward(
      id: id,
      host: host,
      requests: requests.map((r) => r.copy()).toList(),
      process: process,
      startedAt: DateTime.now(),
      onExit: (code, stderr) {
        forward.markExited(code, stderr);
        _forwards.remove(id);
        notifyListeners();
      },
    );

    exitFuture.then((code) {
      final stderr = stderrBuffer.toString();
      forward.onExit(code, stderr);
    });

    _forwards[id] = forward;
    notifyListeners();
    return forward;
  }

  Future<void> stopForward(String id) async {
    final forward = _forwards[id];
    if (forward == null) return;
    await forward.close();
    _forwards.remove(id);
    notifyListeners();
  }

  Future<void> stopAll() async {
    final ids = _forwards.keys.toList();
    for (final id in ids) {
      await stopForward(id);
    }
  }

  void _installSignalHandlers() {
    for (final signal in [
      ProcessSignal.sigint,
      ProcessSignal.sigterm,
      ProcessSignal.sighup,
    ]) {
      try {
        final sub = signal.watch().listen((_) async {
          await stopAll();
        });
        _signalSubscriptions.add(sub);
      } catch (_) {
        // Some signals are not available on all platforms; ignore.
      }
    }
  }

  @override
  void dispose() {
    for (final sub in _signalSubscriptions) {
      sub.cancel();
    }
    stopAll();
    super.dispose();
  }
}

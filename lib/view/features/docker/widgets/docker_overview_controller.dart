import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/features/docker/services/docker_engine_service.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

/// Controller that owns Docker overview snapshot/loading state and selection.
class DockerOverviewController extends ChangeNotifier {
  DockerOverviewController({
    required this.docker,
    this.contextName,
    this.remoteHost,
    this.shellService,
  }) : engineService = DockerEngineService(docker: docker);

  final DockerClientService docker;
  final DockerEngineService engineService;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;

  Future<EngineSnapshot>? snapshot;
  bool containersHydrated = false;
  List<DockerContainer> cachedContainers = const [];
  final Set<String> selectedContainerIds = {};
  final Set<String> selectedImageKeys = {};
  final Set<String> selectedNetworkKeys = {};
  final Set<String> selectedVolumeKeys = {};
  final Map<String, String> containerActionInProgress = {};
  final Map<String, String> imageActionInProgress = {};
  int? focusedContainerIndex;
  int? containerAnchorIndex;

  bool get isRemote => remoteHost != null && shellService != null;

  Future<void> initialize() async {
    snapshot = loadSnapshot();
  }

  Future<EngineSnapshot> loadSnapshot() {
    return runWithRetry(
      () => engineService.fetch(
        contextName: contextName,
        remoteHost: remoteHost,
        shell: shellService,
      ),
      retry: isRemote,
    );
  }

  void refresh() {
    containersHydrated = false;
    snapshot = loadSnapshot();
    notifyListeners();
  }

  Future<void> hotReload() async {
    try {
      final newSnapshot = await loadSnapshot();
      snapshot = Future.value(newSnapshot);
      containersHydrated = false;
      notifyListeners();
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Hot reload failed',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      // On error, fall back to full refresh
      refresh();
    }
  }

  List<DockerContainer> ensureHydrated(EngineSnapshot data) {
    if (!containersHydrated) {
      cachedContainers = data.containers;
      containersHydrated = true;
    }
    return cachedContainers;
  }

  Future<T> runWithRetry<T>(
    Future<T> Function() operation, {
    bool retry = false,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Docker retry operation failed',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      if (!retry) rethrow;
      await Future.delayed(const Duration(milliseconds: 350));
      return operation();
    }
  }

  void updateContainerSelection(
    String key, {
    required bool isTouch,
    int? index,
  }) {
    _updateSelection(
      selectedContainerIds,
      key,
      isTouch: isTouch,
      index: index,
      total: cachedContainers.length,
    );
    focusedContainerIndex = index ?? focusedContainerIndex;
    containerAnchorIndex ??= index;
    notifyListeners();
  }

  void updateSimpleSelection(
    Set<String> set,
    String key, {
    required bool isTouch,
  }) {
    _updateSelection(set, key, isTouch: isTouch);
    notifyListeners();
  }

  void replaceSelection(
    Set<String> set,
    Set<String> tableKeys,
    Iterable<String> selected,
  ) {
    set
      ..removeAll(tableKeys)
      ..addAll(selected);
    notifyListeners();
  }

  void _updateSelection(
    Set<String> set,
    String key, {
    required bool isTouch,
    int? index,
    int? total,
  }) {
    final hardware = HardwareKeyboard.instance;
    final multi = hardware.isControlPressed || hardware.isMetaPressed;
    final additiveTouch = isTouch && set.isNotEmpty;
    final additive = multi || additiveTouch;
    if (additive) {
      if (set.contains(key)) {
        set.remove(key);
      } else {
        set.add(key);
      }
      return;
    }
    if (hardware.isShiftPressed &&
        index != null &&
        total != null &&
        total > 0 &&
        containerAnchorIndex != null) {
      set.clear();
      final anchor = containerAnchorIndex!.clamp(0, total - 1);
      final target = index.clamp(0, total - 1);
      final start = anchor < target ? anchor : target;
      final end = anchor > target ? anchor : target;
      for (var i = start; i <= end; i++) {
        if (i >= 0 && i < cachedContainers.length) {
          set.add(cachedContainers[i].id);
        }
      }
      return;
    }
    set
      ..clear()
      ..add(key);
    if (index != null) {
      containerAnchorIndex = index;
    }
  }

  void selectAllContainers() {
    selectedContainerIds
      ..clear()
      ..addAll(cachedContainers.map((c) => c.id));
    focusedContainerIndex = cachedContainers.isEmpty
        ? null
        : cachedContainers.length - 1;
    containerAnchorIndex = cachedContainers.isEmpty ? null : 0;
    notifyListeners();
  }

  void markContainerAction(String id, String action) {
    containerActionInProgress[id] = action;
    notifyListeners();
  }

  void clearContainerAction(String id) {
    if (containerActionInProgress.remove(id) != null) {
      notifyListeners();
    }
  }

  void markImageBusy(String imageId, String action) {
    imageActionInProgress[imageId] = action;
    notifyListeners();
  }

  void clearImageAction(String imageId) {
    if (imageActionInProgress.remove(imageId) != null) {
      notifyListeners();
    }
  }

  void clearAllImageActions() {
    if (imageActionInProgress.isNotEmpty) {
      imageActionInProgress.clear();
      notifyListeners();
    }
  }

  void markProjectBusy(String project, String action) {
    for (final c in cachedContainers) {
      if (c.composeProject == project) {
        containerActionInProgress[c.id] = 'compose $action';
      }
    }
    notifyListeners();
  }

  void updateCachedContainers(List<DockerContainer> next) {
    cachedContainers = next;
    notifyListeners();
  }

  void mapCachedContainers(DockerContainer Function(DockerContainer) mapper) {
    cachedContainers = cachedContainers.map(mapper).toList();
    notifyListeners();
  }

  Set<String> projectContainerIds(String project) {
    return cachedContainers
        .where((c) => c.composeProject == project)
        .map((c) => c.id)
        .toSet();
  }

  Future<List<DockerContainer>> fetchContainers() {
    return engineService.fetchContainers(
      contextName: contextName,
      remoteHost: remoteHost,
      shell: shellService,
    );
  }

  List<String> composeServices(String project) {
    final services =
        cachedContainers
            .where(
              (c) => c.composeProject == project && c.composeService != null,
            )
            .map((c) => c.composeService!)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return services;
  }
}

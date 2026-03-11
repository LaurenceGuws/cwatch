import 'dart:async';

import 'package:cwatch/controller/adapters/docker_overview_ui_adapter.dart';
import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/model/features/docker/services/container_distro_key.dart';
import 'package:cwatch/model/features/docker/services/container_distro_manager.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

import 'docker_overview_action_state.dart';

class DockerOverviewRuntimeState {
  DockerOverviewRuntimeState({
    required DockerOverviewController controller,
    required ContainerDistroManager containerDistroManager,
    required DockerOverviewActionState actionState,
    required DockerOverviewUiAdapter uiAdapter,
  }) : _controller = controller,
       _containerDistroManager = containerDistroManager,
       _actionState = actionState,
       _uiAdapter = uiAdapter;

  final DockerOverviewController _controller;
  final ContainerDistroManager _containerDistroManager;
  final DockerOverviewActionState _actionState;
  final DockerOverviewUiAdapter _uiAdapter;

  void ensureContainerDistroOnDemand(Iterable<DockerContainer> containers) {
    for (final container in containers) {
      if (!container.isRunning) {
        continue;
      }
      final key = containerDistroCacheKey(container);
      if (_containerDistroManager.hasCached(key)) {
        continue;
      }
      unawaited(
        _containerDistroManager.ensureDistroForContainer(
          container,
          contextName: _controller.contextName,
          remoteHost: _controller.remoteHost,
          shellService: _controller.shellService,
        ),
      );
    }
  }

  Future<DateTime?> loadStartTime(DockerContainer container) async {
    try {
      if (_controller.remoteHost != null && _controller.shellService != null) {
        final output = await _controller.shellService!.runCommand(
          _controller.remoteHost!,
          "docker inspect -f '{{.State.StartedAt}}' ${container.id}",
          timeout: const Duration(seconds: 8),
        );
        final raw = output.trim().replaceAll('"', '');
        return DateTime.tryParse(raw);
      }
      return await _controller.docker.inspectContainerStartTime(
        id: container.id,
        context: _controller.contextName,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load container start time for ${container.name}',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> updateContainerAfterRestart(DockerContainer container) async {
    final startedAt = await loadStartTime(container);
    _controller.updateCachedContainers(
      _actionState.applyRestartedContainer(
        _controller.cachedContainers,
        container,
        startedAt: startedAt,
      ),
    );
  }

  Future<void> updateContainerAfterStart(DockerContainer container) async {
    final startedAt = await loadStartTime(container);
    _controller.updateCachedContainers(
      _actionState.applyStartedContainer(
        _controller.cachedContainers,
        container,
        startedAt: startedAt,
      ),
    );
  }

  void markContainerStopped(String containerId) {
    _controller.updateCachedContainers(
      _actionState.applyStoppedContainer(
        _controller.cachedContainers,
        containerId,
      ),
    );
  }

  Future<void> syncProjectContainers(String project) async {
    try {
      final allContainers = await _controller.fetchContainers();
      _controller.updateCachedContainers(
        _actionState.mergeProjectContainers(
          cached: _controller.cachedContainers,
          fetched: allContainers,
          project: project,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to sync compose project $project',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      _uiAdapter.showSnackBar('Compose sync failed: $error');
    }
  }
}

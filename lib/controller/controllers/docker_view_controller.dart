import 'package:flutter/foundation.dart';

import 'package:cwatch/model/models/docker_context.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class DockerViewController extends ChangeNotifier {
  DockerViewController({required this.docker});

  final DockerClientService docker;

  Future<List<DockerContext>>? _contextsFuture;
  List<DockerContext>? _cachedContexts;
  Exception? _contextsError;

  Future<List<DockerContext>>? get contextsFuture => _contextsFuture;
  List<DockerContext>? get cachedContexts => _cachedContexts;
  Exception? get contextsError => _contextsError;

  Future<List<DockerContext>> loadContexts() async {
    if (_contextsFuture != null) {
      return _contextsFuture!;
    }
    _contextsFuture = _loadContexts();
    try {
      _cachedContexts = await _contextsFuture;
      _contextsError = null;
    } catch (error, stackTrace) {
      _contextsError = error is Exception ? error : Exception(error.toString());
      AppLogger().warn(
        'Failed to load docker contexts',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      notifyListeners();
    }
    return _cachedContexts!;
  }

  Future<List<DockerContext>> _loadContexts() async {
    try {
      return await docker.listContexts();
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load docker contexts',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void refreshContexts() {
    _contextsFuture = null;
    _cachedContexts = null;
    _contextsError = null;
    notifyListeners();
  }
}

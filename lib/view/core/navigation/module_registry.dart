import 'package:flutter/foundation.dart';

import 'shell_module.dart';

/// Simple registry for shell modules. Supports add/remove and notifies listeners.
class ModuleRegistry extends ChangeNotifier {
  ModuleRegistry([List<ShellModuleView>? initialModules]) {
    if (initialModules != null) {
      _modules.addAll(initialModules);
    }
  }

  final List<ShellModuleView> _modules = [];

  List<ShellModuleView> get modules => List.unmodifiable(_modules);

  void register(ShellModuleView module) {
    if (_modules.any((m) => m.id == module.id)) {
      return;
    }
    _modules.add(module);
    notifyListeners();
  }

  void unregister(String id) {
    _modules.removeWhere((module) => module.id == id);
    notifyListeners();
  }
}

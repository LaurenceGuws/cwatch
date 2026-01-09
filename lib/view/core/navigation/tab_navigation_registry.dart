typedef TabNavigationCallback = bool Function();

/// Allows shell-level shortcut handlers to invoke tab navigation on whichever
/// module is active without coupling to individual tab implementations.
class TabNavigationHandle {
  const TabNavigationHandle({required this.next, required this.previous});

  final TabNavigationCallback next;
  final TabNavigationCallback previous;
}

class TabNavigationRegistry {
  TabNavigationRegistry._();

  static final TabNavigationRegistry instance = TabNavigationRegistry._();

  final Map<String, TabNavigationHandle> _handles = {};

  void register(String moduleId, TabNavigationHandle handle) {
    _handles[moduleId] = handle;
  }

  void unregister(String moduleId, TabNavigationHandle handle) {
    final current = _handles[moduleId];
    if (identical(current, handle)) {
      _handles.remove(moduleId);
    }
  }

  TabNavigationHandle? forModule(String moduleId) => _handles[moduleId];
}

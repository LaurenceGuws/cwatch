import '../../models/app_settings.dart';
import 'shortcut_binding.dart';
import 'shortcut_definition.dart';

class ShortcutResolver {
  const ShortcutResolver(this.settings);

  final AppSettings? settings;

  ShortcutBinding? bindingFor(String actionId) {
    final source = _bindingStringFor(actionId);
    return ShortcutBinding.tryParse(source);
  }

  Map<String, ShortcutBinding> bindingsForIds(Iterable<String> actionIds) {
    final map = <String, ShortcutBinding>{};
    for (final id in actionIds) {
      final binding = bindingFor(id);
      if (binding != null) {
        map[id] = binding;
      }
    }
    return map;
  }

  String? _bindingStringFor(String actionId) {
    final override = settings?.shortcutBindings[actionId]?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return ShortcutCatalog.find(actionId)?.defaultBinding;
  }
}

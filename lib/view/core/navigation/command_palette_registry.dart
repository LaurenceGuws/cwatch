import 'dart:async';
import 'package:flutter/material.dart';

class CommandPaletteEntry {
  const CommandPaletteEntry({
    required this.id,
    required this.label,
    required this.onSelected,
    this.category = 'Commands',
    this.description,
    this.icon,
  });

  final String id;
  final String label;
  final String? description;
  final String category;
  final IconData? icon;
  final FutureOr<void> Function() onSelected;
}

typedef CommandPaletteLoader = FutureOr<List<CommandPaletteEntry>> Function();

class CommandPaletteHandle {
  const CommandPaletteHandle({required this.loader});
  final CommandPaletteLoader loader;
}

/// Registry for modules to expose palette entries to the shell.
class CommandPaletteRegistry {
  CommandPaletteRegistry._();

  static final CommandPaletteRegistry instance = CommandPaletteRegistry._();

  final Map<String, CommandPaletteHandle> _handles = {};

  void register(String moduleId, CommandPaletteHandle handle) {
    _handles[moduleId] = handle;
  }

  void unregister(String moduleId, CommandPaletteHandle handle) {
    final current = _handles[moduleId];
    if (identical(current, handle)) {
      _handles.remove(moduleId);
    }
  }

  CommandPaletteHandle? forModule(String moduleId) => _handles[moduleId];
}

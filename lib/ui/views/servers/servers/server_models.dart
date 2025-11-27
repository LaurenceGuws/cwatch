import 'package:flutter/material.dart';

import '../../../../models/explorer_context.dart';
import '../../../../models/server_action.dart';
import '../../../../models/ssh_host.dart';
import '../../../theme/nerd_fonts.dart';
import '../../shared/tabs/tab_chip.dart';

/// Server tab data model
class ServerTab {
  ServerTab({
    required this.id,
    required this.host,
    required this.action,
    required this.bodyKey,
    this.customName,
    this.explorerContext,
    TabOptionsController? optionsController,
  }) : optionsController = optionsController ?? TabOptionsController();

  final String id;
  final SshHost host;
  final ServerAction action;
  final GlobalKey bodyKey;
  final String? customName;
  final ExplorerContext? explorerContext;
  final TabOptionsController optionsController;

  String get title => _displayName;

  String get label => _displayName;

  String get _displayName =>
      (customName?.trim().isNotEmpty ?? false) ? customName!.trim() : host.name;

  IconData get icon {
    switch (action) {
      case ServerAction.empty:
        return NerdIcon.folderOpen.data;
      case ServerAction.fileExplorer:
        return NerdIcon.folder.data;
      case ServerAction.connectivity:
        return NerdIcon.accessPoint.data;
      case ServerAction.resources:
        return NerdIcon.database.data;
      case ServerAction.terminal:
        return NerdIcon.terminal.data;
      case ServerAction.trash:
        return Icons.delete_outline;
      case ServerAction.editor:
        return Icons.edit_note;
    }
  }

  ServerTab copyWith({
    String? id,
    SshHost? host,
    ServerAction? action,
    GlobalKey? bodyKey,
    String? customName,
    bool setCustomName = false,
    ExplorerContext? explorerContext,
    TabOptionsController? optionsController,
  }) {
    return ServerTab(
      id: id ?? this.id,
      host: host ?? this.host,
      action: action ?? this.action,
      bodyKey: bodyKey ?? this.bodyKey,
      customName: setCustomName ? customName : this.customName,
      explorerContext: explorerContext ?? this.explorerContext,
      optionsController: optionsController ?? this.optionsController,
    );
  }
}

/// Placeholder host for empty tabs
class PlaceholderHost extends SshHost {
  const PlaceholderHost()
      : super(name: 'Servers', hostname: '', port: 0, available: true);
}

/// Trash host for trash tabs
class TrashHost extends SshHost {
  const TrashHost()
      : super(name: 'Trash', hostname: '', port: 0, available: true);
}

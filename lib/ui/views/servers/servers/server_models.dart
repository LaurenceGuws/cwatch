import 'package:flutter/material.dart';

import '../../../../models/ssh_host.dart';
import '../../../theme/nerd_fonts.dart';

/// Server tab data model
class ServerTab {
  const ServerTab({
    required this.id,
    required this.host,
    required this.action,
    required this.bodyKey,
    this.customName,
  });

  final String id;
  final SshHost host;
  final ServerAction action;
  final GlobalKey bodyKey;
  final String? customName;

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
      case ServerAction.trash:
        return Icons.delete_outline;
    }
  }

  ServerTab copyWith({
    String? id,
    SshHost? host,
    ServerAction? action,
    GlobalKey? bodyKey,
    String? customName,
    bool setCustomName = false,
  }) {
    return ServerTab(
      id: id ?? this.id,
      host: host ?? this.host,
      action: action ?? this.action,
      bodyKey: bodyKey ?? this.bodyKey,
      customName: setCustomName ? customName : this.customName,
    );
  }
}

/// Server action enum
enum ServerAction { fileExplorer, connectivity, resources, empty, trash }

/// Placeholder host for empty tabs
class PlaceholderHost extends SshHost {
  const PlaceholderHost()
      : super(name: 'Explorer', hostname: '', port: 0, available: true);
}

/// Trash host for trash tabs
class TrashHost extends SshHost {
  const TrashHost()
      : super(name: 'Trash', hostname: '', port: 0, available: true);
}

/// Servers menu action enum
enum ServersMenuAction { openTrash }

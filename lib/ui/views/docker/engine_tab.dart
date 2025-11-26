import 'package:flutter/material.dart';

class EngineTab {
  const EngineTab({
    required this.id,
    required this.title,
    required this.label,
    required this.icon,
    required this.body,
    this.canRename = false,
    this.canDrag = true,
    this.isPicker = false,
    this.workspaceState,
  });

  final String id;
  final String title;
  final String label;
  final IconData icon;
  final Widget body;
  final bool canRename;
  final bool canDrag;
  final bool isPicker;
  final Object? workspaceState;

  EngineTab copyWith({
    String? id,
    String? title,
    String? label,
    IconData? icon,
    Widget? body,
    bool? canRename,
    bool? canDrag,
    bool? isPicker,
    Object? workspaceState,
  }) {
    return EngineTab(
      id: id ?? this.id,
      title: title ?? this.title,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      body: body ?? this.body,
      canRename: canRename ?? this.canRename,
      canDrag: canDrag ?? this.canDrag,
      isPicker: isPicker ?? this.isPicker,
      workspaceState: workspaceState ?? this.workspaceState,
    );
  }
}

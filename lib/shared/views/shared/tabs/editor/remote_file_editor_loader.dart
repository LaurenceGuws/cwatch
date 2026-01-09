import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/app/adapters/remote_file_editor_ui_adapter.dart';
import 'package:cwatch/app/controllers/remote_file_editor_controller.dart';
import 'package:cwatch/ui/bindings/remote_file_editor_binding.dart';

import '../../../../../models/ssh_host.dart';
import '../../../../../services/settings/app_settings_controller.dart';
import '../../../../../services/ssh/builtin/builtin_ssh_key_service.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../tab_chip.dart';
import 'remote_file_editor_tab.dart';

class RemoteFileEditorLoader extends StatefulWidget {
  const RemoteFileEditorLoader({
    super.key,
    required this.host,
    required this.shellService,
    required this.path,
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
    this.optionsController,
    this.helperText,
    this.onSave,
    this.initialContent,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;
  final TabOptionsController? optionsController;
  final String? helperText;
  final Future<void> Function(String content)? onSave;
  final String? initialContent;

  @override
  State<RemoteFileEditorLoader> createState() => _RemoteFileEditorLoaderState();
}

class _RemoteFileEditorLoaderState extends State<RemoteFileEditorLoader> {
  final RemoteFileEditorBinding _binding = const RemoteFileEditorBinding();
  late RemoteFileEditorController _controller;
  late RemoteFileEditorUiAdapter _uiAdapter;
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _uiAdapter = _binding.createUiAdapter(context: context);
    _controller = _binding.createController(
      context: context,
      host: widget.host,
      shellService: widget.shellService,
      path: widget.path,
      onSave: widget.onSave,
      uiAdapter: _uiAdapter,
    );
    _contentFuture = _controller.loadContent(
      initialContent: widget.initialContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load file: ${snapshot.error}'));
        }
        final content = snapshot.data ?? '';
        return RemoteFileEditorTab(
          controller: _controller,
          uiAdapter: _uiAdapter,
          path: widget.path,
          initialContent: content,
          settingsController: widget.settingsController,
          keyService: widget.keyService,
          hostsFuture: widget.hostsFuture,
          helperText: widget.helperText,
          optionsController: widget.optionsController,
        );
      },
    );
  }
}

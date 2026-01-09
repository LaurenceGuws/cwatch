import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/remote_file_editor_ui_adapter.dart';
import 'package:cwatch/controller/controllers/remote_file_editor_controller.dart';
import 'package:cwatch/controller/di/bindings/remote_file_editor_binding.dart';

import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/controller/di/bindings/settings_binding.dart';
import '../tab_chip.dart';
import 'remote_file_editor_tab.dart';

class RemoteFileEditorLoader extends StatefulWidget {
  const RemoteFileEditorLoader({
    super.key,
    required this.path,
    required this.controllerBuilder,
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
    this.optionsController,
    this.helperText,
    this.initialContent,
  });

  final String path;
  final RemoteFileEditorController Function(RemoteFileEditorUiAdapter uiAdapter)
  controllerBuilder;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;
  final TabOptionsController? optionsController;
  final String? helperText;
  final String? initialContent;

  @override
  State<RemoteFileEditorLoader> createState() => _RemoteFileEditorLoaderState();
}

class _RemoteFileEditorLoaderState extends State<RemoteFileEditorLoader> {
  final RemoteFileEditorBinding _binding = const RemoteFileEditorBinding();
  final SettingsBinding _settingsBinding = const SettingsBinding();
  late RemoteFileEditorController _controller;
  late RemoteFileEditorUiAdapter _uiAdapter;
  late SettingsController _settingsController;
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _uiAdapter = _binding.createUiAdapter(context: context);
    _controller = widget.controllerBuilder(_uiAdapter);
    final settingsUiAdapter = _settingsBinding.createUiAdapter(
      context: context,
    );
    _settingsController = _settingsBinding.createController(
      settingsController: widget.settingsController,
      keyService: widget.keyService,
      hostsFuture: widget.hostsFuture,
      uiAdapter: settingsUiAdapter,
    );
    _contentFuture = _controller.loadContent(
      initialContent: widget.initialContent,
    );
  }

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
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
          settingsController: _settingsController,
          helperText: widget.helperText,
          optionsController: widget.optionsController,
        );
      },
    );
  }
}

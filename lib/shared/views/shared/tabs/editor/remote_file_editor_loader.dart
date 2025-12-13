import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../models/ssh_host.dart';
import '../../../../../services/settings/app_settings_controller.dart';
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
    this.optionsController,
    this.helperText,
    this.onSave,
    this.initialContent,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final AppSettingsController settingsController;
  final TabOptionsController? optionsController;
  final String? helperText;
  final Future<void> Function(String content)? onSave;
  final String? initialContent;

  @override
  State<RemoteFileEditorLoader> createState() => _RemoteFileEditorLoaderState();
}

class _RemoteFileEditorLoaderState extends State<RemoteFileEditorLoader> {
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = widget.initialContent != null
        ? Future<String>.value(widget.initialContent)
        : widget.shellService.readFile(widget.host, widget.path);
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
          host: widget.host,
          shellService: widget.shellService,
          path: widget.path,
          initialContent: content,
          onSave:
              widget.onSave ??
              (value) => widget.shellService.writeFile(
                widget.host,
                widget.path,
                value,
              ),
          settingsController: widget.settingsController,
          helperText: widget.helperText,
          optionsController: widget.optionsController,
        );
      },
    );
  }
}

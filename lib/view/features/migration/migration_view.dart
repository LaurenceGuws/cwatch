import 'dart:io';

import 'package:flutter/material.dart';

import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/zide/zide_ffi_backend_config.dart';
import 'package:cwatch/model/services_infra/zide/zide_ffi_exception.dart';
import 'package:cwatch/model/services_infra/zide/zide_ffi_smoke_service.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/section_nav_bar.dart';
import 'widgets/zide_editor_canvas.dart';
import 'widgets/zide_terminal_canvas.dart';

class MigrationView extends StatefulWidget {
  const MigrationView({
    super.key,
    required this.settingsController,
    required this.zideFfiSmokeService,
    this.leading,
  });

  final AppSettingsController settingsController;
  final ZideFfiSmokeService zideFfiSmokeService;
  final Widget? leading;

  @override
  State<MigrationView> createState() => _MigrationViewState();
}

class _MigrationViewState extends State<MigrationView> {
  bool _running = false;
  bool _quietRegression = true;
  bool _suspendPageScroll = false;
  String _output = 'No migration checks run yet.';
  String _exportStatus = 'No report exported yet.';

  Future<void> _runTask(Future<String> Function() task) async {
    if (_running) {
      return;
    }
    setState(() {
      _running = true;
    });
    try {
      final result = await task();
      if (!mounted) {
        return;
      }
      setState(() {
        _output = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _output = 'Error: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _exportOutput() async {
    final report = _output.trim();
    if (report.isEmpty || report == 'No migration checks run yet.') {
      setState(() {
        _exportStatus = 'Nothing to export yet.';
      });
      return;
    }

    try {
      final home = Platform.environment['HOME'] ?? '.';
      final dir = Directory('$home/.cache/cwatch/zide_reports');
      await dir.create(recursive: true);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File('${dir.path}/zide_migration_$timestamp.log');
      await file.writeAsString(report);
      if (!mounted) {
        return;
      }
      setState(() {
        _exportStatus = 'Exported report: ${file.path}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportStatus = 'Export failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        final settings = widget.settingsController.settings;
        final config = ZideFfiBackendConfig(settings: settings);
        final spacing = context.appTheme.spacing;

        String terminalPath;
        String editorPath;
        try {
          terminalPath = config.resolveTerminalLibraryPath();
        } on ZideFfiException catch (error) {
          terminalPath = 'Unavailable: ${error.message}';
        }
        try {
          editorPath = config.resolveEditorLibraryPath();
        } on ZideFfiException catch (error) {
          editorPath = 'Unavailable: ${error.message}';
        }

        return Column(
          children: [
            SectionNavBar(
              title: 'Migration Lab',
              tabs: const [],
              showTitle: true,
              leading: widget.leading,
              enableWindowDrag: !settings.windowUseSystemDecorations,
            ),
            Expanded(
              child: ListView(
                physics: _suspendPageScroll
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: spacing.inset(horizontal: 1.5, vertical: 1),
                children: [
                  Card(
                    child: Padding(
                      padding: spacing.inset(horizontal: 1.5, vertical: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Experimental backend status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: spacing.sm),
                          SelectableText(
                            'enabled=${config.enabled}\n'
                            'terminal_lib=$terminalPath\n'
                            'editor_lib=$editorPath',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Card(
                    child: Padding(
                      padding: spacing.inset(horizontal: 1.5, vertical: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Terminal Widget Prototype',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: spacing.sm),
                          ZideTerminalCanvas(
                            settingsController: widget.settingsController,
                            onPointerHoverChanged: (hovering) {
                              if (!mounted || _suspendPageScroll == hovering) {
                                return;
                              }
                              setState(() {
                                _suspendPageScroll = hovering;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Card(
                    child: Padding(
                      padding: spacing.inset(horizontal: 1.5, vertical: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Editor Widget Prototype',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: spacing.sm),
                          ZideEditorCanvas(
                            settingsController: widget.settingsController,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Card(
                    child: Padding(
                      padding: spacing.inset(horizontal: 1.5, vertical: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: spacing.sm,
                            runSpacing: spacing.sm,
                            children: [
                              FilledButton.icon(
                                onPressed: _running
                                    ? null
                                    : () => _runTask(
                                        widget.zideFfiSmokeService.runSmoke,
                                      ),
                                icon: const Icon(Icons.science_outlined),
                                label: const Text('Run full smoke'),
                              ),
                              FilledButton.icon(
                                onPressed: _running
                                    ? null
                                    : () => _runTask(
                                        () => widget.zideFfiSmokeService
                                            .runSanityCheck(
                                              quiet: _quietRegression,
                                            ),
                                      ),
                                icon: const Icon(Icons.verified_outlined),
                                label: const Text('Run sanity'),
                              ),
                              FilledButton.icon(
                                onPressed: _running
                                    ? null
                                    : () => _runTask(
                                        () => widget.zideFfiSmokeService
                                            .runRegressionPack(
                                              quiet: _quietRegression,
                                            ),
                                      ),
                                icon: const Icon(Icons.fact_check_outlined),
                                label: const Text('Run regression pack'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _running
                                    ? null
                                    : () => _runTask(
                                        widget
                                            .zideFfiSmokeService
                                            .runTerminalSmokeOnly,
                                      ),
                                icon: const Icon(Icons.terminal),
                                label: const Text('Terminal smoke'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _running
                                    ? null
                                    : () => _runTask(
                                        widget
                                            .zideFfiSmokeService
                                            .runEditorSmokeOnly,
                                      ),
                                icon: const Icon(Icons.code),
                                label: const Text('Editor smoke'),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.sm),
                          Row(
                            children: [
                              Switch(
                                value: _quietRegression,
                                onChanged: _running
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _quietRegression = value;
                                        });
                                      },
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Quiet regression mode (reduced terminal lifecycle verbosity)',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Card(
                    child: Padding(
                      padding: spacing.inset(horizontal: 1.5, vertical: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Output',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: spacing.sm),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _exportOutput,
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('Export output'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _exportStatus,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.sm),
                          SelectableText(_output),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

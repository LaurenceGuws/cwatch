import 'dart:io';
import 'dart:math' as math;

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
  bool _canvasFocusMode = false;
  int _canvasTab = 0;
  double _outputPanelHeight = 180;
  double _splitTerminalFraction = 0.6;
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
              child: Padding(
                padding: spacing.inset(horizontal: 1.5, vertical: 1),
                child: Column(
                  children: [
                    if (!_canvasFocusMode) ...[
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
                    ],
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const splitterHeight = 10.0;
                          const minCanvasHeight = 220.0;
                          const minOutputHeight = 100.0;
                          final maxOutputHeight = math.max(
                            minOutputHeight,
                            constraints.maxHeight -
                                minCanvasHeight -
                                splitterHeight,
                          );
                          final outputHeight = _canvasFocusMode
                              ? 0.0
                              : _outputPanelHeight.clamp(
                                  minOutputHeight,
                                  maxOutputHeight,
                                );
                          final canvasHeight = _canvasFocusMode
                              ? constraints.maxHeight
                              : math.max(
                                  minCanvasHeight,
                                  constraints.maxHeight -
                                      outputHeight -
                                      splitterHeight,
                                );
                          return Column(
                            children: [
                              SizedBox(
                                height: canvasHeight,
                                child: Card(
                                  child: Padding(
                                    padding: spacing.inset(
                                      horizontal: 1.5,
                                      vertical: 1,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Canvas Workspace',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              tooltip: _canvasFocusMode
                                                  ? 'Exit canvas focus mode'
                                                  : 'Enter canvas focus mode',
                                              onPressed: () {
                                                setState(() {
                                                  _canvasFocusMode =
                                                      !_canvasFocusMode;
                                                });
                                              },
                                              icon: Icon(
                                                _canvasFocusMode
                                                    ? Icons.fullscreen_exit
                                                    : Icons.fullscreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: spacing.sm),
                                        SegmentedButton<int>(
                                          segments: const [
                                            ButtonSegment<int>(
                                              value: 0,
                                              icon: Icon(Icons.terminal),
                                              label: Text('Terminal'),
                                            ),
                                            ButtonSegment<int>(
                                              value: 1,
                                              icon: Icon(Icons.code),
                                              label: Text('Editor'),
                                            ),
                                            ButtonSegment<int>(
                                              value: 2,
                                              icon: Icon(
                                                Icons.view_agenda_outlined,
                                              ),
                                              label: Text('Split'),
                                            ),
                                          ],
                                          selected: {_canvasTab},
                                          onSelectionChanged: (selection) {
                                            setState(() {
                                              _canvasTab = selection.first;
                                            });
                                          },
                                        ),
                                        SizedBox(height: spacing.sm),
                                        Expanded(
                                          child: _canvasTab == 0
                                              ? ZideTerminalCanvas(
                                                  settingsController:
                                                      widget.settingsController,
                                                )
                                              : _canvasTab == 1
                                              ? ZideEditorCanvas(
                                                  settingsController:
                                                      widget.settingsController,
                                                )
                                              : LayoutBuilder(
                                                  builder: (context, split) {
                                                    const splitHandle = 8.0;
                                                    const minPane = 120.0;
                                                    final paneSpace = math.max(
                                                      0.0,
                                                      split.maxHeight -
                                                          splitHandle,
                                                    );
                                                    final maxTop = math.max(
                                                      minPane,
                                                      paneSpace - minPane,
                                                    );
                                                    final topHeight =
                                                        (paneSpace *
                                                                _splitTerminalFraction)
                                                            .clamp(
                                                              minPane,
                                                              maxTop,
                                                            );
                                                    final bottomHeight = math
                                                        .max(
                                                          minPane,
                                                          paneSpace - topHeight,
                                                        );
                                                    return Column(
                                                      children: [
                                                        SizedBox(
                                                          height: topHeight,
                                                          child: ZideTerminalCanvas(
                                                            settingsController:
                                                                widget
                                                                    .settingsController,
                                                          ),
                                                        ),
                                                        MouseRegion(
                                                          cursor:
                                                              SystemMouseCursors
                                                                  .resizeUpDown,
                                                          child: GestureDetector(
                                                            behavior:
                                                                HitTestBehavior
                                                                    .translucent,
                                                            onVerticalDragUpdate: (details) {
                                                              final nextTop =
                                                                  (topHeight +
                                                                          details
                                                                              .delta
                                                                              .dy)
                                                                      .clamp(
                                                                        minPane,
                                                                        maxTop,
                                                                      );
                                                              setState(() {
                                                                _splitTerminalFraction =
                                                                    paneSpace <=
                                                                        0
                                                                    ? _splitTerminalFraction
                                                                    : nextTop /
                                                                          paneSpace;
                                                              });
                                                            },
                                                            child: SizedBox(
                                                              height:
                                                                  splitHandle,
                                                              child: Center(
                                                                child: Container(
                                                                  width: 56,
                                                                  height: 4,
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.outlineVariant.withValues(
                                                                          alpha:
                                                                              0.9,
                                                                        ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          999,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: bottomHeight,
                                                          child: ZideEditorCanvas(
                                                            settingsController:
                                                                widget
                                                                    .settingsController,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (!_canvasFocusMode) ...[
                                MouseRegion(
                                  cursor: SystemMouseCursors.resizeUpDown,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onVerticalDragUpdate: (details) {
                                      setState(() {
                                        _outputPanelHeight =
                                            (_outputPanelHeight -
                                                    details.delta.dy)
                                                .clamp(
                                                  minOutputHeight,
                                                  maxOutputHeight,
                                                );
                                      });
                                    },
                                    child: SizedBox(
                                      height: splitterHeight,
                                      child: Center(
                                        child: Container(
                                          width: 76,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: outputHeight,
                                  child: Card(
                                    child: Padding(
                                      padding: spacing.inset(
                                        horizontal: 1.5,
                                        vertical: 1,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Output',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          SizedBox(height: spacing.sm),
                                          Row(
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: _exportOutput,
                                                icon: const Icon(
                                                  Icons.download_outlined,
                                                ),
                                                label: const Text(
                                                  'Export output',
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _exportStatus,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: spacing.sm),
                                          Expanded(
                                            child: SingleChildScrollView(
                                              child: SelectableText(_output),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

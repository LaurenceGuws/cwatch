import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/controller/adapters/external_app_launcher.dart';
import 'package:cwatch/controller/adapters/kubernetes_ui_adapter.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/view/shared/widgets/lists/section_list.dart';
import 'package:cwatch/view/shared/widgets/standard_empty_state.dart';

import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_runtime.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_context_actions.dart';

class KubernetesContextPicker extends StatefulWidget {
  const KubernetesContextPicker({
    super.key,
    required this.tabId,
    required this.settingsController,
    required this.onOpenContext,
    required this.onRefreshContexts,
    this.contextsFuture,
    this.cachedContexts = const [],
  });

  final String tabId;
  final AppSettingsController settingsController;
  final void Function(KubeconfigContext context) onOpenContext;
  final VoidCallback onRefreshContexts;
  final Future<List<KubeconfigContext>>? contextsFuture;
  final List<KubeconfigContext> cachedContexts;

  @override
  State<KubernetesContextPicker> createState() =>
      _KubernetesContextPickerState();
}

class _KubernetesContextPickerState extends State<KubernetesContextPicker> {
  late final KubernetesContextController _contextController;
  late final KubernetesUiAdapter _uiAdapter;
  final Map<String, bool> _collapsedByConfigPath = {};
  final Set<String> _selectedContextKeys = {};

  @override
  void initState() {
    super.initState();
    _contextController = KubernetesRuntime.createContextController();
    _uiAdapter = KubernetesUiAdapter(context: context);
  }

  String _contextSelectionKey(KubeconfigContext ctx) =>
      '${ctx.configPath}|${ctx.name}';

  Future<void> _copyText(String text) => _uiAdapter.copyToClipboard(text);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KubeconfigContext>>(
      future: widget.contextsFuture,
      builder: (context, snapshot) {
        final spacing = context.appTheme.spacing;
        if (snapshot.connectionState == ConnectionState.waiting &&
            widget.cachedContexts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return StandardEmptyState(
            icon: Icons.error_outline,
            message: 'Failed to load Kubernetes contexts: ${snapshot.error}',
            actionLabel: 'Retry',
            onAction: widget.onRefreshContexts,
          );
        }

        final contexts = snapshot.data ?? widget.cachedContexts;
        if (contexts.isEmpty) {
          return StandardEmptyState(
            icon: Icons.hub_outlined,
            message: 'No Kubernetes contexts found.',
            actionLabel: 'Reload',
            onAction: widget.onRefreshContexts,
          );
        }

        final grouped = _contextController.groupByConfigPath(contexts);
        final configPaths = grouped.keys.toList()..sort();

        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: spacing.base),
          itemCount: configPaths.length,
          itemBuilder: (context, index) {
            final configPath = configPaths[index];
            final contextsForPath =
                grouped[configPath] ?? const <KubeconfigContext>[];
            final collapsed = _collapsedByConfigPath[configPath] ?? false;
            final sectionColor = _sectionBackgroundForIndex(context, index);

            return Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: SectionList(
                title: path.basename(configPath),
                backgroundColor: sectionColor,
                trailing: IconButton(
                  icon: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    setState(() {
                      _collapsedByConfigPath[configPath] = !collapsed;
                    });
                  },
                ),
                children: collapsed
                    ? const []
                    : [
                        StructuredDataTable<KubeconfigContext>(
                          rows: contextsForPath,
                          columns: _contextColumns(context),
                          rowHeight: 64,
                          shrinkToContent: true,
                          useZebraStripes: false,
                          surfaceBackgroundColor: sectionColor,
                          primaryDoubleClickOpensContextMenu: true,
                          metadataBuilder: _contextMetadata,
                          onRowTap: widget.onOpenContext,
                          rowContextMenuBuilder: _buildContextMenuActions,
                          onSelectionChanged: (selectedRows) {
                            final tableKeys = contextsForPath
                                .map(_contextSelectionKey)
                                .toSet();
                            setState(() {
                              _selectedContextKeys
                                ..removeAll(tableKeys)
                                ..addAll(
                                  selectedRows.map(_contextSelectionKey),
                                );
                            });
                          },
                        ),
                      ],
              ),
            );
          },
        );
      },
    );
  }

  Color _sectionBackgroundForIndex(BuildContext context, int index) {
    final theme = context.appTheme;
    return index.isEven
        ? theme.section.surface.background
        : theme.section.toolbarBackground;
  }

  List<StructuredDataColumn<KubeconfigContext>> _contextColumns(
    BuildContext context,
  ) {
    final spacing = context.appTheme.spacing;
    return [
      StructuredDataColumn<KubeconfigContext>(
        label: 'Context',
        flex: 3,
        autoFitText: (ctx) => ctx.name,
        cellBuilder: (context, ctx) {
          return Row(
            children: [
              Icon(
                NerdIcon.kubernetes.data,
                size: 18,
                color: Theme.of(context).iconTheme.color,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctx.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      path.basename(ctx.configPath),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ];
  }

  List<StructuredDataChip> _contextMetadata(KubeconfigContext ctx) {
    final chips = <StructuredDataChip>[];
    if (ctx.isCurrent) {
      chips.add(const StructuredDataChip(label: 'Current', icon: Icons.check));
    }
    final namespace = ctx.namespace?.trim();
    if (namespace != null && namespace.isNotEmpty) {
      chips.add(StructuredDataChip(label: 'ns: $namespace'));
    }
    return chips;
  }

  List<StructuredDataMenuAction<KubeconfigContext>> _buildContextMenuActions(
    KubeconfigContext ctx,
    List<KubeconfigContext> selected,
    Offset? anchor,
  ) {
    final selection = selected.isNotEmpty ? selected : [ctx];
    return buildKubernetesContextMenuActions(
      selection: selection,
      cliCommand: widget.settingsController.settings.kubernetesPreferences.cliCommand,
      openContext: widget.onOpenContext,
      copyText: _copyText,
      openConfigFile: (configPath) =>
          ExternalAppLauncher.openConfigFile(configPath, context),
    );
  }
}

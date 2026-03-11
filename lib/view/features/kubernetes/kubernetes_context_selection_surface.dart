import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:cwatch/controller/adapters/external_app_launcher.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/features/settings/settings/kubernetes_settings_controls.dart';
import 'package:cwatch/view/shared/views/shared/tabs/settings/floating_settings_window.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table_host.dart';
import 'package:cwatch/view/shared/widgets/lists/section_list.dart';

import 'package:cwatch/controller/adapters/kubernetes_ui_adapter.dart';
import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'kubernetes_context_actions.dart';
import 'kubernetes_context_list_state.dart';
import 'kubernetes_workspace_shell.dart';

class KubernetesContextSelectionSurface extends StatelessWidget {
  const KubernetesContextSelectionSurface({
    super.key,
    required this.listState,
    required this.contextController,
    required this.workspaceShell,
    required this.settingsController,
    required this.replaceTabId,
    required this.onStateChanged,
    required this.onToggleSettings,
  });

  final KubernetesContextListState listState;
  final KubernetesContextController contextController;
  final KubernetesWorkspaceShell workspaceShell;
  final SettingsController settingsController;
  final String replaceTabId;
  final VoidCallback onStateChanged;
  final VoidCallback onToggleSettings;

  String _contextSelectionKey(KubeconfigContext ctx) =>
      '${ctx.configPath}|${ctx.name}';

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
    BuildContext context,
    KubeconfigContext ctx,
    List<KubeconfigContext> selected,
    Offset? anchor,
  ) {
    final selection = selected.isNotEmpty ? selected : [ctx];
    final uiAdapter = KubernetesUiAdapter(context: context);
    return buildKubernetesContextMenuActions(
      selection: selection,
      cliCommand: settingsController.settings.kubernetesPreferences.cliCommand,
      openContext: (target) => workspaceShell.openContextTab(target),
      copyText: (text) => uiAdapter.copyToClipboard(text),
      openConfigFile: (configPath) =>
          ExternalAppLauncher.openConfigFile(configPath, context),
    );
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

  Color _sectionBackgroundForIndex(BuildContext context, int index) {
    final theme = context.appTheme;
    return index.isEven
        ? theme.section.surface.background
        : theme.section.toolbarBackground;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final list = FutureBuilder<List<KubeconfigContext>>(
      future: listState.contextsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            listState.cachedContexts.isEmpty) {
          return const StructuredDataTableFeedback(
            title: 'Contexts',
            subtitle: 'Loading kubeconfig contexts',
            message: 'Loading contexts...',
            loading: true,
            padding: EdgeInsets.zero,
          );
        }
        if (snapshot.hasError) {
          return StructuredDataTableFeedback(
            title: 'Contexts',
            subtitle: 'Kubeconfig discovery failed',
            message: 'Failed to load Kubernetes contexts: ${snapshot.error}',
            icon: Icons.error_outline,
            actionLabel: 'Retry',
            onAction: workspaceShell.refreshContexts,
            padding: EdgeInsets.zero,
          );
        }

        final contexts = listState.resolveContexts(snapshot);
        if (contexts.isEmpty) {
          return StructuredDataTableFeedback(
            title: 'Contexts',
            subtitle: 'No kubeconfig contexts available',
            message: 'No Kubernetes contexts found.',
            icon: Icons.hub_outlined,
            actionLabel: 'Reload',
            onAction: workspaceShell.refreshContexts,
            padding: EdgeInsets.zero,
          );
        }

        final grouped = listState.groupByConfigPath(contextController, contexts);
        final configPaths = grouped.keys.toList()..sort();
        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: spacing.base),
          itemCount: configPaths.length,
          itemBuilder: (context, index) {
            final configPath = configPaths[index];
            final contextsForPath =
                grouped[configPath] ?? const <KubeconfigContext>[];
            final collapsed = listState.isCollapsed(configPath);
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
                    listState.toggleCollapsed(configPath);
                    onStateChanged();
                  },
                ),
                children: collapsed
                    ? const []
                    : [
                        StructuredDataTableHost(
                          title: 'Contexts',
                          subtitle:
                              '${contextsForPath.length} contexts in this kubeconfig',
                          child: StructuredDataTable<KubeconfigContext>(
                            rows: contextsForPath,
                            columns: _contextColumns(context),
                            rowHeight: 64,
                            shrinkToContent: true,
                            useZebraStripes: false,
                            surfaceBackgroundColor: sectionColor,
                            primaryDoubleClickOpensContextMenu: false,
                            metadataBuilder: _contextMetadata,
                            onRowDoubleTap: (ctx) => workspaceShell.openContextTab(
                              ctx,
                              replaceTabId: replaceTabId,
                            ),
                            rowContextMenuBuilder:
                                (ctx, selected, anchor) => _buildContextMenuActions(
                                  context,
                                  ctx,
                                  selected,
                                  anchor,
                                ),
                            onSelectionChanged: (selectedRows) {
                              listState.updateSelectedRows(
                                contextsForPath,
                                selectedRows,
                                _contextSelectionKey,
                              );
                              onStateChanged();
                            },
                          ),
                        ),
                      ],
              ),
            );
          },
        );
      },
    );

    if (!listState.showListSettings) {
      return list;
    }

    return Stack(
      children: [
        list,
        FloatingSettingsWindow(
          title: 'Kubernetes List Settings',
          onClose: onToggleSettings,
          child: Column(
            children: [
              ListTile(
                title: const Text('Collapse all sections'),
                onTap: () {
                  listState.collapseAll();
                  onStateChanged();
                },
                trailing: const Icon(Icons.expand_less),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                title: const Text('Expand all sections'),
                onTap: () {
                  listState.expandAll();
                  onStateChanged();
                },
                trailing: const Icon(Icons.expand_more),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              KubernetesSettingsControls(
                settings: settingsController.settings,
                settingsController: settingsController,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

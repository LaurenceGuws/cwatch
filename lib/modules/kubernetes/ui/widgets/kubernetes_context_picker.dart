import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/external_app_launcher.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';

import '../kubernetes_context_controller.dart';

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
  final KubernetesContextController _contextController =
      KubernetesContextController();
  final Map<String, bool> _collapsedByConfigPath = {};
  final Set<String> _selectedContextKeys = {};

  String _contextSelectionKey(KubeconfigContext ctx) =>
      '${ctx.configPath}|${ctx.name}';

  List<KubeconfigContext> _selectedContextsForAction(
    KubeconfigContext fallback,
  ) {
    final selected = widget.cachedContexts
        .where(
          (ctx) => _selectedContextKeys.contains(_contextSelectionKey(ctx)),
        )
        .toList(growable: false);
    return selected.isEmpty ? [fallback] : selected;
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load contexts: ${snapshot.error}'),
                SizedBox(height: spacing.lg),
                FilledButton.icon(
                  onPressed: widget.onRefreshContexts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final contexts = snapshot.data ?? widget.cachedContexts;
        if (contexts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No Kubernetes contexts found.'),
                SizedBox(height: spacing.lg),
                FilledButton.icon(
                  onPressed: widget.onRefreshContexts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload'),
                ),
              ],
            ),
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
    final selection = _selectedContextsForAction(ctx);
    final singleSelection = selection.length == 1;

    return [
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Open',
        icon: NerdIcon.kubernetes.data,
        onSelected: (_, primary) => widget.onOpenContext(primary),
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Copy context name',
        icon: NerdIcon.copy.data,
        onSelected: (_, primary) => unawaited(_copyText(primary.name)),
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Copy kubectl command',
        icon: NerdIcon.copy.data,
        onSelected: (_, primary) => unawaited(
          _copyText(
            'kubectl --context=${primary.name} --kubeconfig=${primary.configPath}',
          ),
        ),
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Open kubeconfig',
        icon: Icons.open_in_new,
        enabled: singleSelection,
        onSelected: (_, primary) =>
            ExternalAppLauncher.openConfigFile(primary.configPath, context),
      ),
    ];
  }
}

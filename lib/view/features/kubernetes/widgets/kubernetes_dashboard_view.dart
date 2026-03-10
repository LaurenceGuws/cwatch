import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/kubernetes_dashboard_controller.dart';
import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/models/kubernetes/kubernetes_dashboard_models.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/controller/di/bindings/kubernetes_dashboard_binding.dart';

class KubernetesDashboardView extends StatefulWidget {
  const KubernetesDashboardView({
    super.key,
    required this.context,
    required this.settingsController,
  });

  final KubeconfigContext context;
  final AppSettingsController settingsController;

  @override
  State<KubernetesDashboardView> createState() =>
      _KubernetesDashboardViewState();
}

class _KubernetesDashboardViewState extends State<KubernetesDashboardView> {
  final KubernetesDashboardBinding _binding =
      const KubernetesDashboardBinding();
  late final KubernetesDashboardController _controller;
  late final VoidCallback _controllerListener;
  late final VoidCallback _settingsListener;
  late final TextEditingController _searchController;

  static const String _allNamespacesLabel = 'All namespaces';

  @override
  void initState() {
    super.initState();
    _controller = _binding.create(
      context: widget.context,
      initialBackend: widget.settingsController.settings.kubernetesPreferences.backend,
    );
    _controllerListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _controller.addListener(_controllerListener);
    _settingsListener = _handleSettingsChanged;
    _searchController = TextEditingController();
    widget.settingsController.addListener(_settingsListener);
    _controller.initialize();
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_settingsListener);
    _controller
      ..removeListener(_controllerListener)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSettingsChanged() {
    final next = widget.settingsController.settings.kubernetesPreferences.backend;
    _controller.setBackend(next);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final snapshot = _controller.snapshot;
    final loading = _controller.loading;
    final error = _controller.error;

    if (loading && snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _buildError(context, error);
    }
    if (snapshot == null) {
      return _buildError(context, 'No data available.');
    }
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.lg,
            spacing.lg,
            spacing.md,
          ),
          child: _buildHeader(context, snapshot),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
          child: _buildScopeBar(context, snapshot),
        ),
        if (snapshot.warnings.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
            child: _buildWarnings(context, snapshot.warnings),
          ),
        _buildTabs(context, snapshot),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, KubernetesDashboardSnapshot data) {
    final spacing = context.appTheme.spacing;
    final titleStyle = context.appTheme.typography.sectionTitle;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.summary.contextName, style: titleStyle),
              SizedBox(height: spacing.xs),
              Wrap(
                spacing: spacing.md,
                runSpacing: spacing.xs,
                children: [
                  _metaChip(
                    context,
                    label: data.summary.clusterName,
                    icon: Icons.hub,
                  ),
                  if (data.summary.namespace != null)
                    _metaChip(
                      context,
                      label: 'ns: ${data.summary.namespace}',
                      icon: Icons.folder,
                    ),
                  if (data.summary.server != null)
                    _metaChip(
                      context,
                      label: data.summary.server!,
                      icon: Icons.link,
                    ),
                  _metaChip(
                    context,
                    label: _backendLabel(_controller.backend),
                    icon: Icons.settings_input_component,
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Updated ${_formatTimestamp(data.collectedAt)}',
              style: subtitleStyle,
            ),
            SizedBox(height: spacing.xs),
            FilledButton.icon(
              onPressed: _controller.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScopeBar(
    BuildContext context,
    KubernetesDashboardSnapshot data,
  ) {
    final spacing = context.appTheme.spacing;
    final surface = context.appTheme.section.surface;
    final namespaces = _namespaceOptions(data);
    final scopeValue = namespaces.contains(_controller.namespaceScope)
        ? _controller.namespaceScope
        : _allNamespacesLabel;
    if (scopeValue != _controller.namespaceScope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.setNamespaceScope(scopeValue);
      });
    }
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: surface.radius,
        border: Border.all(color: surface.borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final searchField = TextField(
            controller: _searchController,
            onChanged: (value) => _controller.setSearchQuery(value.trim()),
            decoration: InputDecoration(
              labelText: 'Filter',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _controller.setSearchQuery('');
                      },
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear filter',
                    ),
              isDense: true,
            ),
          );

          final scopeField = DropdownButtonFormField<String>(
            initialValue: scopeValue,
            items: [
              for (final name in namespaces)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) {
              if (value == null) return;
              _controller.setNamespaceScope(value);
            },
            decoration: const InputDecoration(
              labelText: 'Namespace scope',
              isDense: true,
            ),
          );

          if (narrow) {
            return Column(
              children: [
                scopeField,
                SizedBox(height: spacing.sm),
                searchField,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: scopeField),
              SizedBox(width: spacing.md),
              Expanded(flex: 3, child: searchField),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWarnings(BuildContext context, List<String> warnings) {
    final spacing = context.appTheme.spacing;
    final surface = context.appTheme.section.surface;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: surface.radius,
        border: Border.all(color: surface.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, size: context.appTheme.iconSizes.medium),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Warnings', style: Theme.of(context).textTheme.titleSmall),
                SizedBox(height: spacing.xs),
                for (final warning in warnings)
                  Text(warning, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _namespaceOptions(KubernetesDashboardSnapshot data) {
    final names = <String>{for (final row in data.namespaces) row.name}.toList()
      ..sort();
    return [_allNamespacesLabel, ...names];
  }

  List<KubernetesNodeRow> _filterNodes(List<KubernetesNodeRow> rows) {
    return _applySearch(
      rows,
      (row) => [
        row.name,
        row.roles,
        row.kubeletVersion,
        row.ready ? 'ready' : 'not ready',
      ],
    );
  }

  List<KubernetesNamespaceRow> _filterNamespaces(
    List<KubernetesNamespaceRow> rows,
  ) {
    return _applySearch(rows, (row) => [row.name, row.status]);
  }

  List<KubernetesWorkloadRow> _filterWorkloads(
    List<KubernetesWorkloadRow> rows,
  ) {
    final scoped = _applyNamespaceFilter(rows, (row) => row.namespace);
    return _applySearch(scoped, (row) => [row.namespace, row.name, row.ready]);
  }

  List<KubernetesPodRow> _filterPods(List<KubernetesPodRow> rows) {
    final scoped = _applyNamespaceFilter(rows, (row) => row.namespace);
    return _applySearch(
      scoped,
      (row) => [row.namespace, row.name, row.status, row.node],
    );
  }

  List<KubernetesServiceRow> _filterServices(List<KubernetesServiceRow> rows) {
    final scoped = _applyNamespaceFilter(rows, (row) => row.namespace);
    return _applySearch(
      scoped,
      (row) => [row.namespace, row.name, row.type, row.clusterIp, row.ports],
    );
  }

  List<KubernetesEventRow> _filterEvents(List<KubernetesEventRow> rows) {
    final scoped = _applyNamespaceFilter(rows, (row) => row.namespace);
    return _applySearch(
      scoped,
      (row) => [row.namespace, row.reason, row.message],
    );
  }

  List<T> _applyNamespaceFilter<T>(
    List<T> rows,
    String Function(T row) namespaceFor,
  ) {
    if (_controller.namespaceScope == _allNamespacesLabel) {
      return rows;
    }
    return rows
        .where((row) => namespaceFor(row) == _controller.namespaceScope)
        .toList();
  }

  List<T> _applySearch<T>(List<T> rows, List<String?> Function(T row) fields) {
    final query = _controller.searchQuery.toLowerCase();
    if (query.isEmpty) {
      return rows;
    }
    return rows.where((row) {
      for (final field in fields(row)) {
        final value = field?.toLowerCase();
        if (value != null && value.contains(query)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  Widget _buildTabs(BuildContext context, KubernetesDashboardSnapshot data) {
    final spacing = context.appTheme.spacing;
    final filteredNodes = _filterNodes(data.nodes);
    final filteredNamespaces = _filterNamespaces(data.namespaces);
    final filteredWorkloads = _filterWorkloads(data.workloads);
    final filteredPods = _filterPods(data.pods);
    final filteredServices = _filterServices(data.services);
    final filteredEvents = _filterEvents(data.events);
    return Expanded(
      child: DefaultTabController(
        length: 7,
        child: Column(
          children: [
            TabBar(
              labelPadding: EdgeInsets.symmetric(horizontal: spacing.md),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Nodes'),
                Tab(text: 'Namespaces'),
                Tab(text: 'Workloads'),
                Tab(text: 'Pods'),
                Tab(text: 'Services'),
                Tab(text: 'Events'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOverview(
                    context,
                    data,
                    workloads: filteredWorkloads,
                    events: filteredEvents,
                  ),
                  _buildNodes(context, filteredNodes),
                  _buildNamespaces(context, filteredNamespaces),
                  _buildWorkloads(context, filteredWorkloads),
                  _buildPods(context, filteredPods),
                  _buildServices(context, filteredServices),
                  _buildEvents(context, filteredEvents),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(
    BuildContext context,
    KubernetesDashboardSnapshot data, {
    required List<KubernetesWorkloadRow> workloads,
    required List<KubernetesEventRow> events,
  }) {
    final spacing = context.appTheme.spacing;
    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: spacing.md,
            runSpacing: spacing.md,
            children: [
              _summaryCard(
                context,
                title: 'Nodes Ready',
                value: '${data.summary.nodesReady}/${data.summary.nodesTotal}',
                subtitle: 'Kubelet health',
              ),
              _summaryCard(
                context,
                title: 'Namespaces',
                value: data.summary.namespaces.toString(),
                subtitle: 'Active scope',
              ),
              _summaryCard(
                context,
                title: 'Workloads',
                value: data.summary.workloads.toString(),
                subtitle: 'Deployments',
              ),
              _summaryCard(
                context,
                title: 'Pods',
                value: data.summary.pods.toString(),
                subtitle: 'Running + pending',
              ),
              _summaryCard(
                context,
                title: 'Services',
                value: data.summary.services.toString(),
                subtitle: 'Cluster entries',
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          Text('Quick view', style: context.appTheme.typography.sectionTitle),
          SizedBox(height: spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _panel(
                  context,
                  title: 'Nodes',
                  child: _compactNodes(context, data.nodes),
                ),
              ),
              SizedBox(width: spacing.lg),
              Expanded(
                child: _panel(
                  context,
                  title: 'Workloads',
                  child: _compactWorkloads(context, workloads),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          _panel(
            context,
            title: 'Recent events',
            child: _compactEvents(context, events),
          ),
        ],
      ),
    );
  }

  Widget _buildNodes(BuildContext context, List<KubernetesNodeRow> rows) {
    return _tableScaffold(
      context,
      table: StructuredDataTable<KubernetesNodeRow>(
        rows: rows,
        columns: [
          StructuredDataColumn<KubernetesNodeRow>(
            label: 'Node',
            flex: 3,
            autoFitText: (row) => row.name,
            cellBuilder: (context, row) => Text(row.name),
          ),
          StructuredDataColumn<KubernetesNodeRow>(
            label: 'Ready',
            flex: 1,
            autoFitText: (row) => row.ready ? 'Ready' : 'Not Ready',
            cellBuilder: (context, row) =>
                Text(row.ready ? 'Ready' : 'Not Ready'),
          ),
          StructuredDataColumn<KubernetesNodeRow>(
            label: 'Roles',
            flex: 2,
            autoFitText: (row) => row.roles,
            cellBuilder: (context, row) => Text(row.roles),
          ),
          StructuredDataColumn<KubernetesNodeRow>(
            label: 'Version',
            flex: 2,
            autoFitText: (row) => row.kubeletVersion,
            cellBuilder: (context, row) => Text(row.kubeletVersion),
          ),
        ],
        rowHeight: 44,
        useZebraStripes: true,
      ),
    );
  }

  Widget _buildNamespaces(
    BuildContext context,
    List<KubernetesNamespaceRow> rows,
  ) {
    return _tableScaffold(
      context,
      table: StructuredDataTable<KubernetesNamespaceRow>(
        rows: rows,
        columns: [
          StructuredDataColumn<KubernetesNamespaceRow>(
            label: 'Namespace',
            flex: 3,
            autoFitText: (row) => row.name,
            cellBuilder: (context, row) => Text(row.name),
          ),
          StructuredDataColumn<KubernetesNamespaceRow>(
            label: 'Status',
            flex: 1,
            autoFitText: (row) => row.status,
            cellBuilder: (context, row) => Text(row.status),
          ),
        ],
        rowHeight: 44,
        useZebraStripes: true,
      ),
    );
  }

  Widget _buildWorkloads(
    BuildContext context,
    List<KubernetesWorkloadRow> rows,
  ) {
    return _tableScaffold(
      context,
      table: StructuredDataTable<KubernetesWorkloadRow>(
        rows: rows,
        columns: [
          StructuredDataColumn<KubernetesWorkloadRow>(
            label: 'Namespace',
            flex: 2,
            autoFitText: (row) => row.namespace,
            cellBuilder: (context, row) => Text(row.namespace),
          ),
          StructuredDataColumn<KubernetesWorkloadRow>(
            label: 'Workload',
            flex: 3,
            autoFitText: (row) => row.name,
            cellBuilder: (context, row) => Text(row.name),
          ),
          StructuredDataColumn<KubernetesWorkloadRow>(
            label: 'Ready',
            flex: 1,
            autoFitText: (row) => row.ready,
            cellBuilder: (context, row) => Text(row.ready),
          ),
          StructuredDataColumn<KubernetesWorkloadRow>(
            label: 'Replicas',
            flex: 1,
            autoFitText: (row) => row.replicas,
            cellBuilder: (context, row) => Text(row.replicas),
          ),
        ],
        rowHeight: 44,
        useZebraStripes: true,
      ),
    );
  }

  Widget _buildPods(BuildContext context, List<KubernetesPodRow> rows) {
    return _tableScaffold(
      context,
      table: StructuredDataTable<KubernetesPodRow>(
        rows: rows,
        columns: [
          StructuredDataColumn<KubernetesPodRow>(
            label: 'Namespace',
            flex: 2,
            autoFitText: (row) => row.namespace,
            cellBuilder: (context, row) => Text(row.namespace),
          ),
          StructuredDataColumn<KubernetesPodRow>(
            label: 'Pod',
            flex: 3,
            autoFitText: (row) => row.name,
            cellBuilder: (context, row) => Text(row.name),
          ),
          StructuredDataColumn<KubernetesPodRow>(
            label: 'Status',
            flex: 1,
            autoFitText: (row) => row.status,
            cellBuilder: (context, row) => Text(row.status),
          ),
          StructuredDataColumn<KubernetesPodRow>(
            label: 'Node',
            flex: 2,
            autoFitText: (row) => row.node,
            cellBuilder: (context, row) => Text(row.node),
          ),
        ],
        rowHeight: 44,
        useZebraStripes: true,
      ),
    );
  }

  Widget _buildServices(BuildContext context, List<KubernetesServiceRow> rows) {
    return _tableScaffold(
      context,
      table: StructuredDataTable<KubernetesServiceRow>(
        rows: rows,
        columns: [
          StructuredDataColumn<KubernetesServiceRow>(
            label: 'Namespace',
            flex: 2,
            autoFitText: (row) => row.namespace,
            cellBuilder: (context, row) => Text(row.namespace),
          ),
          StructuredDataColumn<KubernetesServiceRow>(
            label: 'Service',
            flex: 3,
            autoFitText: (row) => row.name,
            cellBuilder: (context, row) => Text(row.name),
          ),
          StructuredDataColumn<KubernetesServiceRow>(
            label: 'Type',
            flex: 1,
            autoFitText: (row) => row.type,
            cellBuilder: (context, row) => Text(row.type),
          ),
          StructuredDataColumn<KubernetesServiceRow>(
            label: 'Cluster IP',
            flex: 2,
            autoFitText: (row) => row.clusterIp,
            cellBuilder: (context, row) => Text(row.clusterIp),
          ),
          StructuredDataColumn<KubernetesServiceRow>(
            label: 'Ports',
            flex: 2,
            autoFitText: (row) => row.ports,
            cellBuilder: (context, row) => Text(row.ports),
          ),
        ],
        rowHeight: 44,
        useZebraStripes: true,
      ),
    );
  }

  Widget _buildEvents(BuildContext context, List<KubernetesEventRow> rows) {
    return _tableScaffold(
      context,
      table: StructuredDataTable<KubernetesEventRow>(
        rows: rows,
        columns: [
          StructuredDataColumn<KubernetesEventRow>(
            label: 'Namespace',
            flex: 2,
            autoFitText: (row) => row.namespace,
            cellBuilder: (context, row) => Text(row.namespace),
          ),
          StructuredDataColumn<KubernetesEventRow>(
            label: 'Reason',
            flex: 2,
            autoFitText: (row) => row.reason,
            cellBuilder: (context, row) => Text(row.reason),
          ),
          StructuredDataColumn<KubernetesEventRow>(
            label: 'Message',
            flex: 5,
            autoFitText: (row) => row.message,
            cellBuilder: (context, row) =>
                Text(row.message, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          StructuredDataColumn<KubernetesEventRow>(
            label: 'Age',
            flex: 1,
            autoFitText: (row) => _formatAge(row.timestamp),
            cellBuilder: (context, row) => Text(_formatAge(row.timestamp)),
          ),
        ],
        rowHeight: 52,
        useZebraStripes: true,
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final spacing = context.appTheme.spacing;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Dashboard unavailable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: spacing.sm),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: spacing.lg),
            FilledButton.icon(
              onPressed: _controller.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableScaffold(BuildContext context, {required Widget table}) {
    final spacing = context.appTheme.spacing;
    return Padding(padding: EdgeInsets.all(spacing.lg), child: table);
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
  }) {
    final spacing = context.appTheme.spacing;
    final surface = context.appTheme.section.surface;
    return Container(
      width: 200,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: surface.radius,
        border: Border.all(color: surface.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: spacing.sm),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: spacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final spacing = context.appTheme.spacing;
    final surface = context.appTheme.section.surface;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: surface.radius,
        border: Border.all(color: surface.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: spacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _compactNodes(BuildContext context, List<KubernetesNodeRow> rows) {
    final spacing = context.appTheme.spacing;
    if (rows.isEmpty) {
      return Text(
        'No nodes found.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final visible = rows.take(6).toList();
    return Column(
      children: [
        for (final row in visible)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Row(
              children: [
                Expanded(child: Text(row.name)),
                Text(row.ready ? 'Ready' : 'Not Ready'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _compactWorkloads(
    BuildContext context,
    List<KubernetesWorkloadRow> rows,
  ) {
    final spacing = context.appTheme.spacing;
    if (rows.isEmpty) {
      return Text(
        'No workloads found.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final visible = rows.take(6).toList();
    return Column(
      children: [
        for (final row in visible)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Row(
              children: [
                Expanded(child: Text('${row.namespace}/${row.name}')),
                Text(row.ready),
              ],
            ),
          ),
      ],
    );
  }

  Widget _compactEvents(BuildContext context, List<KubernetesEventRow> rows) {
    final spacing = context.appTheme.spacing;
    if (rows.isEmpty) {
      return Text(
        'No events found.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final visible = rows.take(5).toList();
    return Column(
      children: [
        for (final row in visible)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    _formatAge(row.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${row.reason} - ${row.message}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metaChip(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final spacing = context.appTheme.spacing;
    final surface = context.appTheme.section.surface;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: surface.radius,
        border: Border.all(color: surface.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.appTheme.iconSizes.small),
          SizedBox(width: spacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  String _backendLabel(KubernetesBackend backend) {
    switch (backend) {
      case KubernetesBackend.api:
        return 'API';
      case KubernetesBackend.cli:
        return 'CLI (kubectl)';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatAge(DateTime? timestamp) {
    if (timestamp == null) return '—';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

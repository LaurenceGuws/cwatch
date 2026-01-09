import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/resources_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'resources/process_tree_view.dart';
import 'resources/resource_panels.dart';
import 'resources/resource_widgets.dart';

class ResourcesTab extends StatefulWidget {
  const ResourcesTab({super.key, required this.controller});

  final ResourcesController controller;

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {
  final ProcessTreeController _processTreeController = ProcessTreeController();
  late final ResourcesController _controller;
  late final VoidCallback _controllerListener;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controllerListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _controller.addListener(_controllerListener);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_controllerListener);
    super.dispose();
  }

  Future<void> _refresh() {
    return _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final snapshot = _controller.snapshot;
    final error = _controller.error;
    final history = _controller.historyManager;
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: spacing.all(2),
        children: [
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: spacing.all(2),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (snapshot != null) ...[
            CpuPanel(snapshot: snapshot, cpuHistory: history.cpuHistory),
            SizedBox(height: spacing.lg),
            MemoryPanel(
              snapshot: snapshot,
              memoryHistory: history.memoryHistory,
            ),
            SizedBox(height: spacing.lg),
            NetworkPanel(
              snapshot: snapshot,
              netInHistory: history.netInHistory,
              netOutHistory: history.netOutHistory,
            ),
            SizedBox(height: spacing.lg),
            DisksPanel(
              snapshot: snapshot,
              diskIoHistory: history.diskIoHistory,
            ),
            SizedBox(height: spacing.lg),
            SectionCard(
              title: 'Top Processes',
              subtitle: snapshot.processes.isEmpty
                  ? null
                  : '${snapshot.processes.length} sampled processes',
              trailing: snapshot.processes.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Expand all',
                          icon: const Icon(Icons.unfold_more),
                          onPressed: _processTreeController.expandAll,
                        ),
                        IconButton(
                          tooltip: 'Collapse all',
                          icon: const Icon(Icons.unfold_less),
                          onPressed: _processTreeController.collapseAll,
                        ),
                      ],
                    ),
              child: snapshot.processes.isEmpty
                  ? const Text('No process information available.')
                  : ProcessTreeView(
                      processes: snapshot.processes,
                      controller: _processTreeController,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

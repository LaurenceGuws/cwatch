import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';

import '../theme/app_theme.dart';

typedef PortValidator = Future<bool> Function(int port);

Future<List<PortForwardRequest>?> showPortForwardDialog({
  required BuildContext context,
  required String title,
  required List<PortForwardRequest> requests,
  required PortValidator portValidator,
  List<ActivePortForward> active = const [],
}) {
  return showDialog<List<PortForwardRequest>>(
    context: context,
    builder: (context) => _PortForwardDialog(
      title: title,
      initialRequests: requests,
      portValidator: portValidator,
      activeForwards: active,
    ),
  );
}

class _PortForwardDialog extends StatefulWidget {
  const _PortForwardDialog({
    required this.title,
    required this.initialRequests,
    required this.portValidator,
    required this.activeForwards,
  });

  final String title;
  final List<PortForwardRequest> initialRequests;
  final PortValidator portValidator;
  final List<ActivePortForward> activeForwards;

  @override
  State<_PortForwardDialog> createState() => _PortForwardDialogState();
}

class _PortForwardDialogState extends State<_PortForwardDialog> {
  late final List<PortForwardRequest> _requests;
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, TextEditingController> _remoteControllers = {};
  final Map<int, String?> _errors = {};
  final Map<int, String?> _remoteErrors = {};
  final List<bool> _enabled = [];
  final Map<int, _StatusLabel> _status = {};
  final Map<int, int> _statusToken = {};
  bool _checking = false;
  late final List<ActivePortForward> _activeForwards;
  _SortKey _sortKey = _SortKey.remote;
  bool _sortAsc = true;
  bool get _allSelected => _enabled.every((e) => e);

  @override
  void initState() {
    super.initState();
    _activeForwards = widget.activeForwards;
    _requests = widget.initialRequests.map((r) => r.copy()).toList();
    for (var i = 0; i < _requests.length; i++) {
      _controllers[i] = TextEditingController(
        text: _requests[i].localPort.toString(),
      );
      _remoteControllers[i] = TextEditingController(
        text: _requests[i].remotePort.toString(),
      );
      _enabled.add(true);
      _status[i] = _StatusLabel.checking;
      _statusToken[i] = 0;
    }
    _refreshAllStatuses();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _remoteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final spacing = context.appTheme.spacing;
    final maxWidth = size.width * 0.9;
    final dialogWidth = size.width * 0.9;
    final maxHeight = size.height * 0.8;
    final tableMinWidth = maxWidth < 720 ? 720.0 : maxWidth;
    return AlertDialog(
      title: Text(widget.title),
      insetPadding: EdgeInsets.symmetric(
        horizontal: spacing.xl,
        vertical: spacing.lg,
      ),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: dialogWidth,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_activeForwards.isNotEmpty) ...[
                  Text(
                    'Active forwards',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SizedBox(height: spacing.base * 1.5),
                  Wrap(
                    spacing: spacing.md,
                    runSpacing: spacing.md,
                    children: _activeForwards
                        .map(
                          (f) => Chip(
                            avatar: const Icon(Icons.link, size: 16),
                            label: Text(
                              '${f.host.name}: ${f.requests.map((r) => '${r.localPort}->${r.remotePort}').join(', ')}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: spacing.lg),
                ],
                Column(
                  children: [
                    _buildTableHeader(),
                    Divider(height: spacing.lg),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight * 0.7),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableMinWidth,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (var i = 0; i < _requests.length; i++) ...[
                                  _buildRow(i, _requests[i]),
                                  if (i != _requests.length - 1)
                                    Divider(height: spacing.lg),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: _checking
              ? SizedBox(
                  width: spacing.xl,
                  height: spacing.xl,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    final spacing = context.appTheme.spacing;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg),
      child: Row(
        children: [
          _SortableHeader(
            label: 'Use',
            width: 40,
            onTap: () => _sortBy(_SortKey.use),
            direction: _sortDirectionFor(_SortKey.use),
          ),
          _SortableHeader(
            label: 'Remote port',
            flex: 2,
            onTap: () => _sortBy(_SortKey.remote),
            direction: _sortDirectionFor(_SortKey.remote),
            textStyle: textStyle,
          ),
          _SortableHeader(
            label: 'Local port',
            flex: 2,
            onTap: () => _sortBy(_SortKey.local),
            direction: _sortDirectionFor(_SortKey.local),
            textStyle: textStyle,
          ),
          _SortableHeader(
            label: 'Service',
            width: 200,
            onTap: () => _sortBy(_SortKey.service),
            direction: _sortDirectionFor(_SortKey.service),
            textStyle: textStyle,
          ),
          _SortableHeader(
            label: 'Status',
            width: 140,
            onTap: () => _sortBy(_SortKey.status),
            direction: _sortDirectionFor(_SortKey.status),
            textStyle: textStyle,
          ),
          SizedBox(width: spacing.xl * 3),
        ],
      ),
    );
  }

  Widget _buildRow(int index, PortForwardRequest req) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final serviceLabel = req.label ?? '';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _enabled[index],
                  onChanged: (value) {
                    setState(() => _enabled[index] = value ?? true);
                  },
                ),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _remoteControllers[index],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Remote port',
                      errorText: _remoteErrors[index],
                      prefixIcon: const Icon(Icons.cloud_outlined, size: 18),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        _requests[index].remotePort = parsed;
                      }
                      _refreshStatusFor(index);
                      setState(() => _remoteErrors[index] = null);
                    },
                  ),
                ),
                SizedBox(
                  width: spacing.base * 5,
                  child: const Icon(Icons.arrow_forward, size: 16),
                ),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _controllers[index],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Local port',
                      errorText: _errors[index],
                      prefixIcon: Icon(
                        Icons.lan_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        _requests[index].localPort = parsed;
                      }
                      _refreshStatusFor(index);
                      setState(() => _errors[index] = null);
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md),
                  child: const Icon(Icons.swap_horiz, size: 18),
                ),
                SizedBox(
                  width: 200,
                  child: Text(
                    serviceLabel.isNotEmpty ? serviceLabel : '—',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    _statusFor(index),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _checking || _requests.length == 1
                      ? null
                      : () => _removeMapping(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: _allSelected ? 'Deselect all' : 'Select all',
          icon: Icon(
            _allSelected
                ? Icons.indeterminate_check_box
                : Icons.check_box_outlined,
          ),
          onPressed: _checking ? null : _toggleAll,
        ),
        IconButton(
          tooltip: 'Add mapping',
          icon: const Icon(Icons.add),
          onPressed: _checking ? null : _addMapping,
        ),
        const Spacer(),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _checking = true;
      _errors.clear();
      _remoteErrors.clear();
    });
    final seen = <int, int>{};
    var hasError = false;
    for (var i = 0; i < _requests.length; i++) {
      if (!_enabled[i]) {
        continue;
      }
      final value = _controllers[i]?.text ?? '';
      final parsed = int.tryParse(value);
      if (parsed == null || parsed <= 0 || parsed > 65535) {
        _errors[i] = 'Enter a valid port (1-65535)';
        hasError = true;
        continue;
      }
      _requests[i].localPort = parsed;
      final remoteValue = _remoteControllers[i]?.text ?? '';
      final remoteParsed = int.tryParse(remoteValue);
      if (remoteParsed == null || remoteParsed <= 0 || remoteParsed > 65535) {
        _remoteErrors[i] = 'Enter a valid port (1-65535)';
        hasError = true;
      } else {
        _requests[i].remotePort = remoteParsed;
      }
      if (seen.containsKey(parsed)) {
        _errors[i] = 'Duplicate local port';
        _errors[seen[parsed]!] = 'Duplicate local port';
        hasError = true;
      } else {
        seen[parsed] = i;
      }
    }
    if (hasError) {
      setState(() => _checking = false);
      return;
    }

    for (var i = 0; i < _requests.length; i++) {
      if (!_enabled[i]) continue;
      final port = _requests[i].localPort;
      final available = await widget.portValidator(port);
      if (!available) {
        _errors[i] = 'Port $port is unavailable';
        hasError = true;
      }
    }

    if (hasError) {
      setState(() => _checking = false);
      return;
    }

    if (!mounted) return;
    final filtered = <PortForwardRequest>[];
    for (var i = 0; i < _requests.length; i++) {
      if (_enabled[i]) {
        filtered.add(_requests[i]);
      }
    }
    Navigator.of(context).pop(filtered);
  }

  void _addMapping() {
    final last = _requests.isNotEmpty ? _requests.last : null;
    final newReq = PortForwardRequest(
      remoteHost: last?.remoteHost ?? '127.0.0.1',
      remotePort: last?.remotePort ?? 0,
      localPort: last?.localPort ?? 0,
      label: 'Mapping ${_requests.length + 1}',
    );
    setState(() {
      _requests.add(newReq);
      _controllers[_requests.length - 1] = TextEditingController(
        text: newReq.localPort.toString(),
      );
      _remoteControllers[_requests.length - 1] = TextEditingController(
        text: newReq.remotePort.toString(),
      );
      _enabled.add(true);
      _status[_requests.length - 1] = _StatusLabel.checking;
      _statusToken[_requests.length - 1] = 0;
    });
    _refreshStatusFor(_requests.length - 1);
  }

  void _removeMapping(int index) {
    setState(() {
      _controllers.remove(index)?.dispose();
      _remoteControllers.remove(index)?.dispose();
      _requests.removeAt(index);
      _enabled.removeAt(index);
      _errors.remove(index);
      _remoteErrors.remove(index);
      final newControllers = <int, TextEditingController>{};
      final newRemoteControllers = <int, TextEditingController>{};
      for (var i = 0; i < _requests.length; i++) {
        newControllers[i] =
            _controllers[i] ??
            TextEditingController(text: _requests[i].localPort.toString());
        newRemoteControllers[i] =
            _remoteControllers[i] ??
            TextEditingController(text: _requests[i].remotePort.toString());
      }
      _controllers
        ..clear()
        ..addAll(newControllers);
      _remoteControllers
        ..clear()
        ..addAll(newRemoteControllers);
      _status
        ..clear()
        ..addEntries(
          List.generate(
            _requests.length,
            (i) => MapEntry(i, _StatusLabel.checking),
          ),
        );
      _statusToken
        ..clear()
        ..addEntries(List.generate(_requests.length, (i) => MapEntry(i, 0)));
      _applySort();
      _refreshAllStatuses();
    });
  }

  void _toggleAll() {
    final target = !_allSelected;
    setState(() {
      for (var i = 0; i < _enabled.length; i++) {
        _enabled[i] = target;
      }
      _applySort();
      _refreshAllStatuses();
    });
  }

  void _refreshAllStatuses() {
    for (var i = 0; i < _requests.length; i++) {
      _statusToken[i] = _statusToken[i] ?? 0;
      _status[i] = _status[i] ?? _StatusLabel.checking;
      _refreshStatusFor(i);
    }
  }

  Future<void> _refreshStatusFor(int index) async {
    final token = (_statusToken[index] ?? 0) + 1;
    _statusToken[index] = token;
    setState(() {
      _status[index] = _StatusLabel.checking;
    });
    final localPort = _requests[index].localPort;
    final remotePort = _requests[index].remotePort;
    if (localPort <= 0 || localPort > 65535) {
      if (_statusToken[index] != token) return;
      setState(() => _status[index] = _StatusLabel.invalid);
      return;
    }
    final duplicateLocal = _requests.asMap().entries.any((entry) {
      if (entry.key == index) return false;
      if (entry.key >= _enabled.length) return false;
      return _enabled[entry.key] && entry.value.localPort == localPort;
    });
    if (duplicateLocal) {
      if (_statusToken[index] != token) return;
      setState(() => _status[index] = _StatusLabel.duplicate);
      return;
    }
    final active = _activeForwards.any(
      (f) => f.requests.any(
        (r) => r.localPort == localPort && r.remotePort == remotePort,
      ),
    );
    if (active) {
      if (_statusToken[index] != token) return;
      AppLogger.d(
        'Status update idx=$index remote=$remotePort local=$localPort -> active',
        tag: 'PortForward',
      );
      setState(() => _status[index] = _StatusLabel.active);
      return;
    }
    final available = await widget.portValidator(localPort);
    if (_statusToken[index] != token) return;
    final nextStatus = available ? _StatusLabel.inactive : _StatusLabel.busy;
    AppLogger.d(
      'Status update idx=$index remote=$remotePort local=$localPort -> '
      '${nextStatus == _StatusLabel.inactive ? 'inactive' : 'busy'}',
      tag: 'PortForward',
    );
    setState(() {
      _status[index] = nextStatus;
    });
  }

  void _sortBy(_SortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
      _applySort();
    });
  }

  void _applySort() {
    var zipped = List.generate(_requests.length, (i) => i);
    int compareIndices(int a, int b) {
      switch (_sortKey) {
        case _SortKey.use:
          final av = _enabled[a] ? 1 : 0;
          final bv = _enabled[b] ? 1 : 0;
          return av.compareTo(bv);
        case _SortKey.remote:
          return _requests[a].remotePort.compareTo(_requests[b].remotePort);
        case _SortKey.local:
          return _requests[a].localPort.compareTo(_requests[b].localPort);
        case _SortKey.service:
          return (_requests[a].label ?? '').compareTo(_requests[b].label ?? '');
        case _SortKey.status:
          return _statusFor(a).compareTo(_statusFor(b));
      }
    }

    zipped.sort(compareIndices);
    if (!_sortAsc) {
      zipped = zipped.reversed.toList();
    }

    final newRequests = <PortForwardRequest>[];
    final newEnabled = <bool>[];
    final newControllers = <int, TextEditingController>{};
    final newRemoteControllers = <int, TextEditingController>{};
    final newErrors = <int, String?>{};
    final newRemoteErrors = <int, String?>{};
    final newStatus = <int, _StatusLabel>{};
    final newTokens = <int, int>{};

    for (var i = 0; i < zipped.length; i++) {
      final oldIndex = zipped[i];
      newRequests.add(_requests[oldIndex]);
      newEnabled.add(_enabled[oldIndex]);
      newControllers[i] = _controllers[oldIndex]!;
      newRemoteControllers[i] = _remoteControllers[oldIndex]!;
      if (_errors.containsKey(oldIndex)) {
        newErrors[i] = _errors[oldIndex];
      }
      if (_remoteErrors.containsKey(oldIndex)) {
        newRemoteErrors[i] = _remoteErrors[oldIndex];
      }
      newStatus[i] = _status[oldIndex] ?? _StatusLabel.checking;
      newTokens[i] = _statusToken[oldIndex] ?? 0;
    }

    _requests
      ..clear()
      ..addAll(newRequests);
    _enabled
      ..clear()
      ..addAll(newEnabled);
    _controllers
      ..clear()
      ..addAll(newControllers);
    _remoteControllers
      ..clear()
      ..addAll(newRemoteControllers);
    _errors
      ..clear()
      ..addAll(newErrors);
    _remoteErrors
      ..clear()
      ..addAll(newRemoteErrors);
    _status
      ..clear()
      ..addAll(newStatus);
    _statusToken
      ..clear()
      ..addAll(newTokens);
  }

  _SortDirection _sortDirectionFor(_SortKey key) {
    if (_sortKey != key) return _SortDirection.none;
    return _sortAsc ? _SortDirection.asc : _SortDirection.desc;
  }

  String _statusFor(int index) {
    switch (_status[index] ?? _StatusLabel.checking) {
      case _StatusLabel.active:
        return 'active';
      case _StatusLabel.busy:
        return 'local port in use';
      case _StatusLabel.inactive:
        return 'inactive';
      case _StatusLabel.duplicate:
        return 'duplicate mapping';
      case _StatusLabel.invalid:
        return 'invalid port';
      case _StatusLabel.checking:
        return 'checking…';
    }
  }
}

enum _SortKey { use, remote, local, service, status }

enum _SortDirection { none, asc, desc }

enum _StatusLabel { inactive, active, busy, duplicate, invalid, checking }

class _SortableHeader extends StatelessWidget {
  const _SortableHeader({
    required this.label,
    this.flex,
    this.width,
    required this.onTap,
    required this.direction,
    this.textStyle,
  }) : assert(flex == null || width == null);

  final String label;
  final int? flex;
  final double? width;
  final VoidCallback onTap;
  final _SortDirection direction;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final icon = switch (direction) {
      _SortDirection.asc => Icons.arrow_upward,
      _SortDirection.desc => Icons.arrow_downward,
      _ => null,
    };
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: textStyle),
        if (icon != null) ...[SizedBox(width: spacing.sm), Icon(icon, size: spacing.base * 3.5)],
      ],
    );

    final child = InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        child: Align(alignment: Alignment.centerLeft, child: labelWidget),
      ),
    );

    if (flex != null) {
      return Expanded(flex: flex!, child: child);
    }
    return SizedBox(width: width, child: child);
  }
}

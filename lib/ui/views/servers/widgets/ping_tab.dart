import 'package:flutter/material.dart';

import '../../../../models/ssh_host.dart';

class PingTab extends StatefulWidget {
  const PingTab({
    super.key,
    required this.host,
  });

  final SshHost host;

  @override
  State<PingTab> createState() => _PingTabState();
}

class _PingTabState extends State<PingTab> {
  bool _inProgress = false;
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ping ${widget.host.hostname}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _inProgress ? null : _runPingTest,
            icon: const Icon(Icons.wifi_tethering),
            label: Text(_inProgress ? 'Running...' : 'Run Ping Test'),
          ),
          const SizedBox(height: 12),
          if (_inProgress)
            const Text('Sending 4 packets...')
          else if (_result != null)
            Text(
              _result!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            )
          else
            const Text('No recent test.'),
        ],
      ),
    );
  }

  Future<void> _runPingTest() async {
    setState(() {
      _inProgress = true;
      _result = null;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _inProgress = false;
      _result = 'Average latency 24 ms (simulated)';
    });
  }
}

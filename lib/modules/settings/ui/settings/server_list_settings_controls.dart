import 'package:flutter/material.dart';
import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';

class ServerListSettingsControls extends StatelessWidget {
  const ServerListSettingsControls({
    super.key,
    required this.settings,
    required this.settingsController,
    this.hosts,
  });

  final AppSettings settings;
  final AppSettingsController settingsController;
  final List<SshHost>? hosts;

  Map<String, SshHost> _hostIndex() {
    final map = <String, SshHost>{};
    for (final host in hosts ?? const <SshHost>[]) {
      map[host.name.toLowerCase()] = host;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final disabledHosts = settings.disabledServerHosts;
    final index = _hostIndex();
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Show Offline Servers'),
          value: settings.serverShowOffline,
          onChanged: (value) => settingsController.update(
            (s) => s.copyWith(serverShowOffline: value),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('Auto Refresh'),
          value: settings.serverAutoRefresh,
          onChanged: (value) => settingsController.update(
            (s) => s.copyWith(serverAutoRefresh: value),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Disabled servers',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 8),
        if (disabledHosts.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('No disabled servers.'),
          )
        else
          for (final key in disabledHosts)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    index[key] != null
                        ? '${index[key]!.name} (${index[key]!.hostname})'
                        : key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final next = [...disabledHosts]..remove(key);
                    settingsController.update(
                      (s) => s.copyWith(disabledServerHosts: next),
                    );
                  },
                  child: const Text('Enable'),
                ),
              ],
            ),
      ],
    );
  }
}

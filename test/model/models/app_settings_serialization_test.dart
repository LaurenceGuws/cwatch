import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/custom_ssh_host.dart';
import 'package:cwatch/model/models/docker_preferences.dart';
import 'package:cwatch/model/models/editor_preferences.dart';
import 'package:cwatch/model/models/explorer_preferences.dart';
import 'package:cwatch/model/models/input_mode_preference.dart';
import 'package:cwatch/model/models/kubernetes_backend.dart';
import 'package:cwatch/model/models/kubernetes_preferences.dart';
import 'package:cwatch/model/models/shell_preferences.dart';
import 'package:cwatch/model/models/ssh_client_backend.dart';
import 'package:cwatch/model/models/ssh_preferences.dart';
import 'package:cwatch/model/models/terminal_preferences.dart';

void main() {
  group('AppSettings serialization', () {
    test('writes grouped preference and config sections', () {
      final settings = AppSettings(
        themeMode: ThemeMode.dark,
        debugMode: true,
        zoomFactor: 1.25,
        serverAutoRefresh: false,
        serverShowOffline: false,
        shellPreferences: const ShellPreferences(
          sidebarWidth: 320,
          destination: 'docker',
          sidebarCollapsed: true,
          sidebarPlacement: 'left',
          useSystemDecorations: false,
          closeToTray: true,
        ),
        appFontFamily: 'IBM Plex Sans',
        appThemeKey: 'amber',
        uiDensity: AppUiDensity.comfy,
        inputModePreference: InputModePreference.gestures,
        sshPreferences: const SshPreferences(
          clientBackend: SshClientBackend.builtin,
          builtinHostKeyBindings: {'example.com': 'ssh-ed25519 AAAA'},
          customHosts: [
            CustomSshHost(
              name: 'devbox',
              hostname: '10.0.0.8',
              user: 'alice',
              port: 2222,
            ),
          ],
          customConfigPaths: ['/tmp/ssh_a'],
          disabledConfigPaths: ['/tmp/ssh_disabled'],
          disabledServerHosts: ['legacy-host'],
        ),
        shortcutBindings: const {'openSettings': 'ctrl+,'},
        editorPreferences: const EditorPreferences(
          themeLight: 'github-light',
          themeDark: 'tokyo-night',
          fontFamily: 'Fira Code',
          fontSize: 15,
          lineHeight: 1.5,
        ),
        dockerPreferences: const DockerPreferences(
          remoteHosts: ['tcp://docker-a:2375'],
          selectedContext: 'remote-a',
          logsTail: 123,
        ),
        kubernetesPreferences: const KubernetesPreferences(
          configPaths: ['/tmp/kubeconfig'],
          backend: KubernetesBackend.api,
        ),
        terminalPreferences: const TerminalPreferences(
          fontFamily: 'Iosevka',
          fontSize: 13,
          lineHeight: 1.2,
          paddingX: 6,
          paddingY: 9,
          themeDark: 'catppuccin-mocha',
          themeLight: 'papercolor-light',
        ),
        fileTransferUploadConcurrency: 4,
        fileTransferDownloadConcurrency: 5,
        explorerPreferences: const ExplorerPreferences(
          rowHeight: 44,
          showBreadcrumbs: false,
        ),
      );

      final json = settings.toJson();

      expect(json['shellPreferences'], {
        'sidebarWidth': 320.0,
        'destination': 'docker',
        'sidebarCollapsed': true,
        'sidebarPlacement': 'left',
        'useSystemDecorations': false,
        'closeToTray': true,
      });
      expect(json['editorPreferences'], {
        'themeLight': 'github-light',
        'themeDark': 'tokyo-night',
        'fontFamily': 'Fira Code',
        'fontSize': 15.0,
        'lineHeight': 1.5,
      });
      expect(json['terminalPreferences'], {
        'fontFamily': 'Iosevka',
        'fontSize': 13.0,
        'lineHeight': 1.2,
        'paddingX': 6.0,
        'paddingY': 9.0,
        'themeDark': 'catppuccin-mocha',
        'themeLight': 'papercolor-light',
      });
      expect(json['explorerPreferences'], {
        'rowHeight': 44.0,
        'showBreadcrumbs': false,
      });
      expect(json['sshPreferences'], {
        'clientBackend': 'builtin',
        'builtinHostKeyBindings': {'example.com': 'ssh-ed25519 AAAA'},
        'customHosts': [
          {
            'name': 'devbox',
            'hostname': '10.0.0.8',
            'user': 'alice',
            'port': 2222,
          },
        ],
        'customConfigPaths': ['/tmp/ssh_a'],
        'disabledConfigPaths': ['/tmp/ssh_disabled'],
        'disabledServerHosts': ['legacy-host'],
      });
      expect(json['kubernetesPreferences'], {
        'configPaths': ['/tmp/kubeconfig'],
        'backend': 'api',
      });
      expect(json['dockerPreferences'], {
        'remoteHosts': ['tcp://docker-a:2375'],
        'selectedContext': 'remote-a',
        'logsTail': 123,
      });
    });

    test('does not write obsolete flat preference or config keys', () {
      final json = const AppSettings().toJson();

      expect(json.containsKey('shellSidebarWidth'), isFalse);
      expect(json.containsKey('shellDestination'), isFalse);
      expect(json.containsKey('windowUseSystemDecorations'), isFalse);
      expect(json.containsKey('closeToTray'), isFalse);
      expect(json.containsKey('editorThemeLight'), isFalse);
      expect(json.containsKey('editorThemeDark'), isFalse);
      expect(json.containsKey('editorFontFamily'), isFalse);
      expect(json.containsKey('editorFontSize'), isFalse);
      expect(json.containsKey('editorLineHeight'), isFalse);
      expect(json.containsKey('terminalFontFamily'), isFalse);
      expect(json.containsKey('terminalFontSize'), isFalse);
      expect(json.containsKey('terminalLineHeight'), isFalse);
      expect(json.containsKey('terminalPaddingX'), isFalse);
      expect(json.containsKey('terminalPaddingY'), isFalse);
      expect(json.containsKey('terminalThemeDark'), isFalse);
      expect(json.containsKey('terminalThemeLight'), isFalse);
      expect(json.containsKey('explorerRowHeight'), isFalse);
      expect(json.containsKey('explorerShowBreadcrumbs'), isFalse);
      expect(json.containsKey('sshClientBackend'), isFalse);
      expect(json.containsKey('builtinSshHostKeyBindings'), isFalse);
      expect(json.containsKey('customSshHosts'), isFalse);
      expect(json.containsKey('customSshConfigPaths'), isFalse);
      expect(json.containsKey('disabledSshConfigPaths'), isFalse);
      expect(json.containsKey('disabledServerHosts'), isFalse);
      expect(json.containsKey('kubernetesConfigPaths'), isFalse);
      expect(json.containsKey('kubernetesBackend'), isFalse);
      expect(json.containsKey('dockerRemoteHosts'), isFalse);
      expect(json.containsKey('dockerSelectedContext'), isFalse);
      expect(json.containsKey('dockerLogsTail'), isFalse);
    });

    test('round-trips grouped sections through fromJson and toJson', () {
      final input = <String, dynamic>{
        'themeMode': 'dark',
        'debugMode': true,
        'zoomFactor': 1.4,
        'serverAutoRefresh': false,
        'serverShowOffline': false,
        'shellPreferences': {
          'sidebarWidth': 280.0,
          'destination': 'servers',
          'sidebarCollapsed': true,
          'sidebarPlacement': 'right',
          'useSystemDecorations': false,
          'closeToTray': true,
        },
        'appFontFamily': 'Atkinson Hyperlegible',
        'appThemeKey': 'green',
        'uiDensity': 'comfy',
        'inputModePreference': 'gestures',
        'sshPreferences': {
          'clientBackend': 'builtin',
          'builtinHostKeyBindings': {'ssh.example': 'ssh-rsa BBBB'},
          'customHosts': [
            {
              'name': 'prod',
              'hostname': 'prod.internal',
              'user': 'root',
              'port': 22,
            },
          ],
          'customConfigPaths': ['/configs/ssh'],
          'disabledConfigPaths': ['/configs/disabled'],
          'disabledServerHosts': ['skip-me'],
        },
        'shortcutBindings': {'commandPalette': 'ctrl+shift+p'},
        'editorPreferences': {
          'themeLight': 'solarized-light',
          'themeDark': 'gruvbox-dark',
          'fontFamily': 'JetBrains Mono',
          'fontSize': 16.0,
          'lineHeight': 1.6,
        },
        'dockerPreferences': {
          'remoteHosts': ['ssh://docker-host'],
          'selectedContext': 'prod-context',
          'logsTail': 250,
        },
        'kubernetesPreferences': {
          'configPaths': ['/kube/config'],
          'backend': 'api',
        },
        'terminalPreferences': {
          'fontFamily': 'MesloLGS NF',
          'fontSize': 12.0,
          'lineHeight': 1.25,
          'paddingX': 7.0,
          'paddingY': 11.0,
          'themeDark': 'night-owl',
          'themeLight': 'quiet-light',
        },
        'fileTransferUploadConcurrency': 6,
        'fileTransferDownloadConcurrency': 7,
        'explorerPreferences': {
          'rowHeight': 40.0,
          'showBreadcrumbs': false,
        },
      };

      final settings = AppSettings.fromJson(input);
      final output = settings.toJson();

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.shellPreferences.sidebarWidth, 280.0);
      expect(settings.shellPreferences.destination, 'servers');
      expect(settings.shellPreferences.closeToTray, isTrue);
      expect(settings.editorPreferences.themeDark, 'gruvbox-dark');
      expect(settings.editorPreferences.fontSize, 16.0);
      expect(settings.terminalPreferences.themeLight, 'quiet-light');
      expect(settings.explorerPreferences.rowHeight, 40.0);
      expect(settings.sshPreferences.clientBackend, SshClientBackend.builtin);
      expect(settings.sshPreferences.customHosts.single.name, 'prod');
      expect(settings.kubernetesPreferences.backend, KubernetesBackend.api);
      expect(settings.dockerPreferences.remoteHosts, ['ssh://docker-host']);
      expect(settings.dockerPreferences.selectedContext, 'prod-context');
      expect(settings.dockerLogsTailClamped, 250);

      expect(output['shellPreferences'], input['shellPreferences']);
      expect(output['editorPreferences'], input['editorPreferences']);
      expect(output['terminalPreferences'], input['terminalPreferences']);
      expect(output['explorerPreferences'], input['explorerPreferences']);
      expect(output['sshPreferences'], input['sshPreferences']);
      expect(output['kubernetesPreferences'], input['kubernetesPreferences']);
      expect(output['dockerPreferences'], input['dockerPreferences']);
    });
  });
}

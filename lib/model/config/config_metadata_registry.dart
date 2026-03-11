import 'package:cwatch/model/config/config_metadata_descriptor.dart';
import 'package:cwatch/model/models/editor_preferences.dart';
import 'package:cwatch/model/models/explorer_preferences.dart';
import 'package:cwatch/model/models/shell_preferences.dart';
import 'package:cwatch/model/models/terminal_preferences.dart';

const configMetadataRegistry = <ConfigGroupDescriptor>[
  ConfigGroupDescriptor(
    key: 'shellPreferences',
    label: 'Shell Preferences',
    description: 'Window and shell chrome preferences.',
    order: 10,
    modelType: ShellPreferences,
    fields: [
      ConfigFieldDescriptor(
        key: 'sidebarWidth',
        label: 'Sidebar Width',
        description:
            'Preferred sidebar width when the shell sidebar is visible.',
        kind: ConfigValueKind.doubleValue,
        unit: 'px',
      ),
      ConfigFieldDescriptor(
        key: 'destination',
        label: 'Destination',
        description: 'Preferred default shell destination identifier.',
        kind: ConfigValueKind.string,
      ),
      ConfigFieldDescriptor(
        key: 'sidebarCollapsed',
        label: 'Sidebar Collapsed',
        description: 'Whether the shell sidebar starts collapsed.',
        kind: ConfigValueKind.boolean,
        defaultValueDoc: 'false',
      ),
      ConfigFieldDescriptor(
        key: 'sidebarPlacement',
        label: 'Sidebar Placement',
        description: 'Placement mode for the shell sidebar.',
        kind: ConfigValueKind.string,
        defaultValueDoc: 'dynamic',
      ),
      ConfigFieldDescriptor(
        key: 'useSystemDecorations',
        label: 'Use System Decorations',
        description: 'Whether the shell uses native window decorations.',
        kind: ConfigValueKind.boolean,
        defaultValueDoc: 'true',
      ),
      ConfigFieldDescriptor(
        key: 'closeToTray',
        label: 'Close To Tray',
        description: 'Whether closing the shell minimizes to the tray instead.',
        kind: ConfigValueKind.boolean,
        defaultValueDoc: 'false',
      ),
    ],
  ),
  ConfigGroupDescriptor(
    key: 'editorPreferences',
    label: 'Editor Preferences',
    description: 'Shared editor theme and typography preferences.',
    order: 20,
    modelType: EditorPreferences,
    fields: [
      ConfigFieldDescriptor(
        key: 'themeLight',
        label: 'Light Theme',
        description: 'Preferred editor theme when the app is in light mode.',
        kind: ConfigValueKind.string,
      ),
      ConfigFieldDescriptor(
        key: 'themeDark',
        label: 'Dark Theme',
        description: 'Preferred editor theme when the app is in dark mode.',
        kind: ConfigValueKind.string,
      ),
      ConfigFieldDescriptor(
        key: 'fontFamily',
        label: 'Font Family',
        description: 'Preferred editor font family.',
        kind: ConfigValueKind.string,
      ),
      ConfigFieldDescriptor(
        key: 'fontSize',
        label: 'Font Size',
        description: 'Preferred editor font size.',
        kind: ConfigValueKind.doubleValue,
        unit: 'pt',
        defaultValueDoc: '14',
      ),
      ConfigFieldDescriptor(
        key: 'lineHeight',
        label: 'Line Height',
        description: 'Preferred editor line height multiplier.',
        kind: ConfigValueKind.doubleValue,
        defaultValueDoc: '1.35',
      ),
    ],
  ),
  ConfigGroupDescriptor(
    key: 'terminalPreferences',
    label: 'Terminal Preferences',
    description: 'Shared terminal theme, spacing, and typography preferences.',
    order: 30,
    modelType: TerminalPreferences,
    fields: [
      ConfigFieldDescriptor(
        key: 'fontFamily',
        label: 'Font Family',
        description: 'Preferred terminal font family.',
        kind: ConfigValueKind.string,
        defaultValueDoc: 'JetBrainsMono Nerd Font',
      ),
      ConfigFieldDescriptor(
        key: 'fontSize',
        label: 'Font Size',
        description: 'Preferred terminal font size.',
        kind: ConfigValueKind.doubleValue,
        unit: 'pt',
        defaultValueDoc: '14',
      ),
      ConfigFieldDescriptor(
        key: 'lineHeight',
        label: 'Line Height',
        description: 'Preferred terminal line height multiplier.',
        kind: ConfigValueKind.doubleValue,
        defaultValueDoc: '1.15',
      ),
      ConfigFieldDescriptor(
        key: 'paddingX',
        label: 'Horizontal Padding',
        description: 'Horizontal terminal padding.',
        kind: ConfigValueKind.doubleValue,
        unit: 'px',
        defaultValueDoc: '8',
      ),
      ConfigFieldDescriptor(
        key: 'paddingY',
        label: 'Vertical Padding',
        description: 'Vertical terminal padding.',
        kind: ConfigValueKind.doubleValue,
        unit: 'px',
        defaultValueDoc: '10',
      ),
      ConfigFieldDescriptor(
        key: 'themeDark',
        label: 'Dark Theme',
        description: 'Preferred terminal theme in dark mode.',
        kind: ConfigValueKind.string,
        defaultValueDoc: 'dracula',
      ),
      ConfigFieldDescriptor(
        key: 'themeLight',
        label: 'Light Theme',
        description: 'Preferred terminal theme in light mode.',
        kind: ConfigValueKind.string,
        defaultValueDoc: 'solarized-light',
      ),
    ],
  ),
  ConfigGroupDescriptor(
    key: 'explorerPreferences',
    label: 'Explorer Preferences',
    description: 'Shared explorer layout and navigation preferences.',
    order: 40,
    modelType: ExplorerPreferences,
    fields: [
      ConfigFieldDescriptor(
        key: 'rowHeight',
        label: 'Row Height',
        description: 'Preferred explorer row height.',
        kind: ConfigValueKind.doubleValue,
        unit: 'px',
        defaultValueDoc: '36',
      ),
      ConfigFieldDescriptor(
        key: 'showBreadcrumbs',
        label: 'Show Breadcrumbs',
        description: 'Whether the explorer shows breadcrumb navigation.',
        kind: ConfigValueKind.boolean,
        defaultValueDoc: 'true',
      ),
    ],
  ),
];

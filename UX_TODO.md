# UX/UI Standardization & Polish Plan

## 1. Spacing & Layout Standardization
Migrate remaining hardcoded values to `AppThemeTokens` (`context.appTheme.spacing`).

- [ ] **Docker Resources (`lib/modules/docker/ui/widgets/docker_resources.dart`)**
- [x] **Docker Resources (`lib/modules/docker/ui/widgets/docker_resources.dart`)**
    - [x] Replace `EdgeInsets.all(8)` with `spacing.md` (or `spacing.all(2)`).
    - [x] Replace `SizedBox(height: 8)` with `spacing.md`.
    - [x] Replace `SizedBox(height: 16)` with `spacing.xl`.
- [ ] **General Settings Tab (`lib/modules/settings/ui/settings/general_settings_tab.dart`)**
- [x] **General Settings Tab (`lib/modules/settings/ui/settings/general_settings_tab.dart`)**
    - [x] Replace `SizedBox(height: 12)` with `spacing.lg` (or `spacing.base * 3`).
    - [x] Standardize padding `EdgeInsets.symmetric(horizontal: 6, vertical: 4)` -> `spacing.inset(...)`.
- [ ] **Other Settings Tabs**
    - [x] `ServersSettingsTab` (`lib/modules/settings/ui/settings/servers_settings_tab.dart`)
    - [x] `DockerSettingsTab` (`lib/modules/settings/ui/settings/container_settings_tabs.dart`)
    - [x] `TerminalSettingsTab` (`lib/modules/settings/ui/settings/terminal_settings_tab.dart`)
    - [x] `EditorSettingsTab` (`lib/modules/settings/ui/settings/editor_settings_tab.dart`)
    - Replace random `SizedBox(height: 12/16/20)` with consistent spacing tokens.
- [ ] **File Explorer (`lib/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart`)**
    - [x] Replace Drag/Drop overlay color `Colors.blue` with theme token.
    - [x] Standardize `SizedBox` spacing.

## 2. Component Unification
Reduce code duplication and enforce consistent behavior.

- [ ] **Standard Empty State Widget**
    - [x] Create `lib/shared/widgets/standard_empty_state.dart`.
    - [x] Properties: `message`, `icon` (optional), `actionLabel` (optional), `onAction` (optional).
    - [x] Usage: Replace ad-hoc `Center(child: Text(...))` in:
        - [x] `DockerOverview` (`_buildEmptyTab`)
        - [x] `HostList`
        - [x] `FileEntryList`
        - [x] `DockerResources`
- [ ] **Tab Options Helper**
    - [x] Create `lib/shared/mixins/tab_options_mixin.dart` (or similar).
    - [x] Encapsulate the `_pendingTabOptions` / `addPostFrameCallback` logic.
    - [x] Apply to: `RemoteFileEditorTab`, `DockerResources`, `DockerOverview`, `FileExplorerTab`.

## 3. Visual Polish
- [ ] **Charts (`DockerResources`)**
    - [x] Ensure grid lines and tooltips use `AppDockerTokens` (e.g., `chartGrid`).
- [ ] **Command Bar (`CommandBar`)**
    - [x] Ensure consistent padding/decoration matches `InlineSearchBar` or global input theme.

## 4. Input & Form Standardization
- [ ] **Form Spacing**
    - (Optional) Create a `FormSpacer` widget (alias for `SizedBox(height: spacing.lg)`) to ensure all forms have identical vertical rhythm.

## 5. Final Verification
- [ ] Walk through all main tabs (Servers, Docker, Settings, Explorer, Terminal) to verify visual consistency.

## 6. Additional Cleanup (post-scan)
- [x] **Settings Spacing Tokens**
    - [x] `BuiltInSshSettings` (`lib/modules/settings/ui/settings/builtin_ssh_settings.dart`)
    - [x] `ShortcutsSettingsTab` (`lib/modules/settings/ui/settings/shortcuts_settings_tab.dart`)
    - [x] `TerminalSettingsSection` (`lib/modules/settings/ui/settings/terminal_settings_section.dart`)
    - [x] `EditorSettingsSection` (`lib/modules/settings/ui/settings/editor_settings_section.dart`)
    - [x] `DebugLogsTab` (`lib/modules/settings/ui/settings/debug_logs_tab.dart`)
- [x] **Docker + Explorer Polish**
    - [x] `ErrorCard` spacing (`lib/modules/docker/ui/widgets/docker_shared.dart`)
    - [x] `DockerCommandTerminal` dialog spacing (`lib/modules/docker/ui/widgets/docker_command_terminal.dart`)
    - [x] `DockerEnginePicker` empty state spacing (`lib/modules/docker/ui/widgets/docker_engine_picker.dart`)
    - [x] `TrashTab` spacing (`lib/shared/views/shared/tabs/file_explorer/trash_tab.dart`)
    - [x] `DesktopDragSource` placeholder color (`lib/shared/views/shared/tabs/file_explorer/desktop_drag_source.dart`)
    - [x] `PathNavigator` padding spacing (`lib/shared/views/shared/tabs/file_explorer/path_navigator.dart`)
    - [x] `MergeConflictDialog` spacing (`lib/shared/views/shared/tabs/file_explorer/merge_conflict_dialog.dart`)
    - [x] `FileOperationProgressDialog` spacing (`lib/shared/widgets/file_operation_progress_dialog.dart`)
    - [x] `InputHelpDialog` spacing (`lib/shared/widgets/input_help_dialog.dart`)

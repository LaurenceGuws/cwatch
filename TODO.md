## TODO

- Split large UI files for readability:
  - `lib/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart`
  - `lib/modules/docker/ui/widgets/docker_lists.dart`
  - `lib/modules/servers/ui/servers/servers_list.dart`
  - `lib/modules/servers/ui/widgets/resources/connectivity_tab.dart`
  - `lib/modules/servers/ui/widgets/resources/process_tree_view.dart`

- Continue SSH cleanup:
  - Extract helpers from `lib/services/ssh/builtin/builtin_ssh_settings.dart`.
  - Reduce complexity in `lib/services/ssh/builtin/builtin_ssh_client_manager.dart` (identity collection/unlock flow).
  - Keep slimming `lib/services/ssh/builtin/builtin_remote_shell_service.dart` orchestrator as helpers solidify.

- Testing and quality:
  - Run `flutter analyze` and `flutter test --coverage`.
  - Add targeted tests around Docker scan/cache refresh and SSH key unlock flows.

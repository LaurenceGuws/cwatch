# Modularization Plan

This document outlines the plan to improve reusability and modularize larger files in the cwatch codebase.

## Current State

Based on `scc` analysis, the largest files are:

1. **file_explorer_tab.dart** - 2,798 lines, 465 complexity
2. **resources_tab.dart** - 1,857 lines, 112 complexity  
3. **servers_view.dart** - 1,544 lines, 153 complexity
4. **settings_view.dart** - 1,512 lines, 128 complexity

## Completed Work

### file_explorer_tab.dart Modularization

Created the following reusable components in `lib/ui/views/servers/widgets/file_explorer/`:

1. **path_navigator.dart** - Path navigation widget with breadcrumbs and text input
   - `PathNavigator` - Main widget
   - `_BreadcrumbsView` - Breadcrumb navigation
   - `_PathFieldView` - Text field with autocomplete

2. **command_bar.dart** - Command bar for executing SSH commands
   - `CommandBar` - Simple widget for command input

3. **file_selection_controller.dart** - Selection state management
   - `FileSelectionController` - Manages file selection state, drag selection, keyboard navigation

4. **file_operations_service.dart** - File operation handlers
   - `FileOperationsService` - Handles copy, move, delete, download, upload operations
   - Methods: `handlePaste`, `handleDownload`, `handleUpload`

5. **ssh_auth_handler.dart** - SSH authentication handling
   - `SshAuthHandler` - Manages SSH key unlocking, passphrase prompts
   - Methods: `runShell`, `promptUnlock`, `awaitPassphraseInput`

## Remaining Work

### file_explorer_tab.dart

Still need to extract:
- **file_entry_list.dart** - The main file list widget with selection handling
- **context_menu_builder.dart** - Context menu creation logic
- **file_entry_tile.dart** - Individual file entry widget
- Update main `file_explorer_tab.dart` to use all extracted components

### resources_tab.dart (1,857 lines)

Extract into:
- **resource_panels/** - CPU, Memory, Network, Disk panels
- **process_tree/** - Process tree view and related widgets
- **resource_parser.dart** - Parsing logic for SSH command output
- **resource_snapshot.dart** - Data models

### servers_view.dart (1,544 lines)

Extract into:
- **dialogs/** - Add/edit server dialogs, add/edit key dialogs
- **host_list.dart** - Host list widget
- **tab_management.dart** - Tab creation and management logic

### settings_view.dart (1,512 lines)

Extract into:
- **settings_tabs/** - Individual settings tab widgets
- **ssh_key_management/** - SSH key management UI and logic
- **settings_section.dart** - Reusable settings section widget

## Benefits

1. **Reusability** - Components can be reused across different views
2. **Testability** - Smaller units are easier to test
3. **Maintainability** - Easier to locate and fix bugs
4. **Readability** - Smaller files are easier to understand
5. **Separation of Concerns** - Clear boundaries between UI, logic, and state

## Next Steps

1. Complete file_explorer_tab.dart modularization
2. Extract components from resources_tab.dart
3. Extract components from servers_view.dart
4. Extract components from settings_view.dart
5. Update tests to match new structure
6. Update documentation

## File Structure

```
lib/ui/views/servers/widgets/
├── file_explorer/
│   ├── path_navigator.dart ✅
│   ├── command_bar.dart ✅
│   ├── file_selection_controller.dart ✅
│   ├── file_operations_service.dart ✅
│   ├── ssh_auth_handler.dart ✅
│   ├── file_entry_list.dart (TODO)
│   ├── context_menu_builder.dart (TODO)
│   └── file_entry_tile.dart (TODO)
├── resources/
│   ├── resource_panels/ (TODO)
│   ├── process_tree/ (TODO)
│   ├── resource_parser.dart (TODO)
│   └── resource_snapshot.dart (TODO)
└── ...
```


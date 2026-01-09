# Testing Roadmap

This document outlines recommended tests to add to improve code coverage and reliability.

## Priority 1: Critical Business Logic Services

### 1. **ExplorerOps** (`lib/model/services/explorer_ops.dart`)
**Why**: Core file explorer operations - path loading, navigation, search, selection
**Test Cases**:
- `loadPath()` - normal loading, error handling, force reload, skip logic
- `refreshCurrentPath()` - refresh logic, error handling
- `navigateBack()` - history navigation
- `navigateForward()` - forward navigation
- `searchPath()` - search functionality, cancellation
- Selection management
- Path history management

### 2. **PathLoadingService** (`lib/model/services/path_loading_service.dart`)
**Why**: Handles all path loading logic, caching, error recovery
**Test Cases**:
- `loadPath()` - normal load, error handling, path normalization
- `refreshPath()` - refresh logic
- `searchPath()` - search with various options
- `listPath()` - directory listing
- Path normalization edge cases
- Cache hydration

### 3. **FileEditingService** (`lib/model/services/file_editing_service.dart`)
**Why**: File editing, caching, sync operations - critical for data integrity
**Test Cases**:
- `openEditor()` - file opening, error handling
- `openLocally()` - local file session creation
- `syncLocalChanges()` - sync logic, merge conflicts
- `saveFile()` - file saving, error handling
- Cache management
- Merge conflict resolution

### 4. **ExplorerClipboard** (`lib/model/services/explorer_clipboard.dart`)
**Why**: Clipboard operations for copy/cut/paste - user-facing feature
**Test Cases**:
- `setEntry()` / `setEntries()` - setting clipboard content
- `clear()` - clearing clipboard
- `notifyCutCompleted()` - cut operation completion
- `notifyCutsCompleted()` - multiple cuts
- Listener notifications
- Entry retrieval

## Priority 2: Controllers (State Management)

### 5. **TerminalSessionController** (`lib/controller/controllers/terminal_session_controller.dart`)
**Why**: Manages terminal sessions - critical for SSH terminal functionality
**Test Cases**:
- `start()` - session creation, output subscription
- `write()` - writing to terminal
- `resize()` - terminal resizing
- `reset()` - session cleanup
- `dispose()` - resource cleanup
- Error handling

### 6. **ResourcesController** (`lib/controller/controllers/resources_controller.dart`)
**Why**: Manages server resource data (CPU, memory, disk, processes)
**Test Cases**:
- Resource data updates
- Error handling
- Listener notifications
- Data refresh logic

### 7. **DockerViewController** (`lib/controller/controllers/docker_view_controller.dart`)
**Why**: Manages Docker workspace state and operations
**Test Cases**:
- Workspace state management
- Tab management
- Error handling
- State persistence

### 8. **KubernetesResourcesController** (`lib/controller/controllers/kubernetes_resources_controller.dart`)
**Why**: Manages Kubernetes resource data
**Test Cases**:
- Resource data updates
- Error handling
- Listener notifications
- Data refresh logic

## Priority 3: Infrastructure & Utilities

### 9. **ResourceParser** (`lib/model/services/resource_parser.dart`)
**Why**: Parses complex resource data from SSH output - parsing bugs are hard to catch
**Test Cases**:
- `collectSnapshot()` - full snapshot collection
- CPU parsing
- Memory parsing
- Disk usage parsing
- Process tree parsing
- Network stats parsing
- Error handling for malformed data
- Edge cases (empty data, missing sections)

### 10. **Workspace Persistence** (`lib/controller/core/workspace/workspace_persistence.dart`)
**Why**: Persists workspace state - data integrity critical
**Test Cases**:
- `persist()` - saving workspace state
- `restore()` - restoring workspace state
- Signature comparison
- Tab state extraction
- Error handling

### 11. **SSH Key Service** (`lib/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart`)
**Why**: Manages SSH keys - security critical
**Test Cases**:
- `addKey()` - adding keys with/without passphrase
- `unlock()` - key unlocking
- `listKeys()` - listing keys
- `removeKey()` - key removal
- Error handling
- Encryption/decryption

### 12. **ExplorerTrashManager** (`lib/model/services_infra/filesystem/explorer_trash_manager.dart`)
**Why**: Manages trash operations - data safety
**Test Cases**:
- `moveToTrash()` - moving files to trash
- `restoreFromTrash()` - restoring files
- `emptyTrash()` - clearing trash
- Trash entry management
- Error handling

## Priority 4: Integration & Edge Cases

### 13. **FileOperationsService - Extended Tests**
**Why**: Current test covers basics, but needs more edge cases
**Additional Test Cases**:
- Concurrent operations
- Cross-host operations
- Large file transfers
- Error recovery
- Cancellation
- Progress callbacks

### 14. **RemoteShellService Implementations**
**Why**: Test actual SSH implementations
**Test Cases**:
- `ProcessRemoteShellService` - process-based SSH
- `BuiltInRemoteShellService` - built-in SSH
- Connection handling
- Timeout handling
- Error recovery

### 15. **UI Adapters**
**Why**: Test UI adapter logic (mocking BuildContext)
**Test Cases**:
- `FileOperationsUiHandler` - file operation dialogs
- `ExplorerUiAdapter` - explorer UI operations
- Error message display
- Dialog handling

## Priority 5: Widget Tests

### 16. **Critical Widgets**
**Why**: Test UI behavior and user interactions
**Widgets to Test**:
- File explorer list
- Terminal tab
- Editor tab
- Settings views
- Dialog widgets

## Testing Strategy

### Unit Tests (Current Focus)
- Test services in isolation with mocks/fakes
- Test controllers with mocked dependencies
- Test utilities and parsers

### Integration Tests (Future)
- Test service interactions
- Test controller-service integration
- Test workspace persistence end-to-end

### Widget Tests (Future)
- Test critical UI components
- Test user interactions
- Test state updates

## Test Organization

```
test/
├── services/                    # Business logic services
│   ├── explorer_ops_test.dart
│   ├── path_loading_service_test.dart
│   ├── file_editing_service_test.dart
│   ├── explorer_clipboard_test.dart
│   └── resource_parser_test.dart
├── controller/                 # Controllers
│   ├── terminal_session_controller_test.dart
│   ├── resources_controller_test.dart
│   ├── docker_view_controller_test.dart
│   └── kubernetes_resources_controller_test.dart
├── services_infra/             # Infrastructure
│   ├── ssh/
│   │   └── builtin_ssh_key_service_test.dart
│   └── filesystem/
│       └── explorer_trash_manager_test.dart
└── core/                       # Core functionality
    └── workspace/
        └── workspace_persistence_test.dart
```

## Coverage Goals

- **Current**: ~5% (1 test file)
- **Phase 1** (Priority 1-2): ~40% coverage
- **Phase 2** (Priority 3): ~60% coverage
- **Phase 3** (Priority 4-5): ~80% coverage

## Notes

- Follow existing test patterns (fakes, mocks)
- Use `flutter_test` package
- Test error paths as well as happy paths
- Focus on business logic, not implementation details
- Keep tests fast and isolated

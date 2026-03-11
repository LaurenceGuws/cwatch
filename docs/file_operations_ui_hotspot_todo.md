# File Operations UI Hotspot TODO

Status: active
Purpose: track bounded cleanup batches for the current file-operation UI deduplication hotspot.

## Task 27.1: start the file-operation UI hotspot pass
Status: completed

Goal:
- treat file-operation UI deduplication as the next active repo hotspot after the SSH checkpoint
- keep this pass focused on repeated progress/cancellation/result orchestration, not on replacing explorer file-operation behavior

Done definition:
- there is one active file-operation UI TODO for the new pass
- the first bounded batch is named from the current code state

Result:
- file-operation UI deduplication is now the active hotspot pass
- the first bounded batch should reduce repeated transfer-progress orchestration without reopening settings, Docker, SSH, or runtime/composition work

## Task 27.2: define the first bounded file-operation UI batch
Status: completed

Goal:
- choose one concrete file-operation UI cleanup slice with strong DRY value and low behavior risk
- keep the first batch on transfer-progress orchestration rather than changing file-operation semantics

Done definition:
- one first batch is explicit
- the stop condition reflects the current repeated code shape in `FileOperationsUiHandler`

Result:
- the first bounded file-operation UI batch is now:
  - extract shared transfer completion/failure orchestration from `FileOperationsUiHandler`
- target files:
  - [file_operations_ui_handler.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operations_ui_handler.dart)
  - new helper under `lib/controller/adapters/`
- stop condition:
  - repeated progress-dialog dismissal, refresh policy, cancel handling, and success/failure snackbar shaping no longer repeat across download/upload flows
  - focused regression coverage exists for the new helper
  - file-operation semantics and per-item task behavior stay stable

Why this is the right first cut:
- the same transfer-completion and failure orchestration is repeated across download, file upload, folder upload, and dropped-path upload flows
- that support logic is orthogonal to the item-specific upload/download tasks
- this creates a direct regression seam without forcing a broader file-operation rewrite

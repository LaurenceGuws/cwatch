# File Operations UI Hotspot TODO

Status: checkpointed
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

## Task 27.3: define the next bounded file-operation UI batch
Status: completed

Goal:
- choose the next repeated transfer-UI support seam from the current code state
- keep the batch on per-item progress scaffolding rather than changing file-operation semantics

Done definition:
- one next batch is explicit
- the stop condition reflects the repeated item progress code still left in `FileOperationsUiHandler`

Result:
- the next bounded file-operation UI batch is now:
  - extract shared item-progress scaffolding from `FileOperationsUiHandler`
- target files:
  - [file_operations_ui_handler.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operations_ui_handler.dart)
  - new helper under `lib/controller/adapters/`
- stop condition:
  - repeated item start/byte-tracking/complete/fail wiring no longer repeats across download/upload variants
  - focused regression coverage exists for the new helper
  - the per-flow operation work stays stable

Why this is the right next cut:
- after the transfer-session split, the strongest remaining repetition is the per-item progress controller wiring
- that support logic is still orthogonal to the actual download/upload task behavior
- this narrows the handler toward flow orchestration without forcing a broader file-operations redesign

## Task 27.4: define the next bounded file-operation UI batch
Status: completed

Goal:
- choose the next repeated transfer-hosting seam from the current code state
- keep the batch on progress-runtime bootstrap rather than broader operation redesign

Done definition:
- one next batch is explicit
- the stop condition reflects the repeated dialog/controller/session setup still left in `FileOperationsUiHandler`

Result:
- the next bounded file-operation UI batch is now:
  - extract shared transfer runtime bootstrap from `FileOperationsUiHandler`
- target files:
  - [file_operations_ui_handler.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operations_ui_handler.dart)
  - new helper under `lib/controller/adapters/`
- stop condition:
  - repeated progress-dialog creation and transfer-session bootstrap no longer repeats across transfer flows
  - focused regression coverage continues to protect transfer-session behavior
  - per-flow transfer work stays stable

Why this is the right next cut:
- after the transfer-session and item-progress splits, the strongest remaining repetition is the progress runtime bootstrap itself
- that code is still identical across download and upload variants
- this narrows the handler further toward true flow-specific behavior without inventing a broader abstraction

## Task 27.5: checkpoint the file-operation UI hotspot
Status: completed

Goal:
- record that the current file-operation UI pass removed the main repeated transfer scaffolding seam from the current code state
- stop here before forcing weaker flow-specific extractions

Done definition:
- this TODO is checkpointed from the current code state
- completed file-operation UI work is recorded as enforced baseline
- the remaining file-operation weight is described accurately

Result:
- shared transfer completion/failure orchestration now lives in:
  - [file_operation_transfer_session.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operation_transfer_session.dart)
- shared per-item progress scaffolding now lives in:
  - [file_operation_item_progress.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operation_item_progress.dart)
- shared transfer runtime bootstrap now lives in:
  - [file_operation_transfer_runtime.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operation_transfer_runtime.dart)
- [file_operations_ui_handler.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operations_ui_handler.dart) is materially narrower and now hosts mostly flow-specific upload/download behavior
- focused regression coverage exists in:
  - [file_operation_transfer_session_test.dart](/home/home/personal/cwatch/test/controller/adapters/file_operation_transfer_session_test.dart)
  - [file_operation_item_progress_test.dart](/home/home/personal/cwatch/test/controller/adapters/file_operation_item_progress_test.dart)

What remains:
- [file_operations_ui_handler.dart](/home/home/personal/cwatch/lib/controller/adapters/file_operations_ui_handler.dart) still contains distinct flow-specific work for file uploads, directory uploads, dropped-path uploads, and downloads
- that remaining weight is now mostly valid operation-specific behavior rather than the same repeated transfer-UI scaffolding hotspot

Checkpoint rule:
- future file-operation UI work should reopen from fresh evidence in specific transfer flows or broader service/controller boundaries, not from the older repeated progress/cancel/result scaffolding hotspot

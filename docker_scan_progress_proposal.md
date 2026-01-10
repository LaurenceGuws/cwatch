# Docker Remote Scan UI Proposal

## Summary
Replace the Docker remote scan dialog with a reusable progress popup (matching the upload/download progress UI), and ensure scans skip disabled servers. The new popup becomes a shared component for Docker and Kubernetes scans.

## Goals
- Skip disabled servers during scans and avoid probing them at all.
- Provide a consistent progress popup aligned with file transfer UX.
- Introduce a reusable progress widget for other scan flows (Docker, Kubernetes, future modules).

## Current State
- Docker scan UI uses `RemoteScanDialog` (`lib/view/features/docker/widgets/remote_scan_dialog.dart`).
- Scan targets come from `hostsFuture` and include disabled hosts.
- Upload/download progress UI lives in `lib/view/shared/widgets/file_operation_progress_dialog.dart` (`_TransferToast`).

## Proposed Changes
### 1) Respect Disabled Servers
- Filter scan targets to `host.available == true` in:
  - `DockerView._loadRemoteStatuses` (so the UI only lists enabled hosts).
  - `DockerWorkspaceController.discoverRemoteStatuses` (so probes never run against disabled hosts).
- Optional: show a small note like “N disabled servers skipped” in the popup footer.

### 2) Replace RemoteScanDialog
- Remove `RemoteScanDialog` and replace it with a progress popup using the same surface, spacing, and progress bars as the transfer toast UI.
- The popup shows:
  - Title: “Scanning servers for Docker”
  - Overall progress (completed / total hosts + percent bar)
  - Current host being scanned
  - Cancel/close icon to abort the scan

### 3) Reusable Progress Popup Component
Create a shared widget under `lib/view/shared/widgets/` (e.g. `operation_progress_popup.dart`) modeled after `_TransferToast`:

**Suggested API**
```
OperationProgressPopup(
  title: String,
  subtitle: String?,
  total: int,
  completed: int,
  currentItem: String?,
  progress: double,
  icon: IconData?,
  onCancel: VoidCallback?,
)
```

**Styling**
- Use the same `section.surface` styling and `LinearPercentIndicator` colors as `_TransferToast`.
- Align padding/typography with the transfer popup for consistent UX.

### 4) Docker Scan Integration
- Replace `DockerUiAdapter.showRemoteScanDialog` with a new method that shows the progress popup.
- Maintain the current cancellation flow via `_scanToken` and `_cancelledScans`.
- Feed progress data from `hostsListenable` + `statusesListenable`.

### 5) Kubernetes Scan Integration (Follow‑up)
- Apply the same popup component when Kubernetes scans are triggered.
- Keep progress data sources local to the Kubernetes controller/view.

## Notes / Open Questions
- Do we want a compact mode for tiny scans (1–2 hosts)?
- Should the popup auto-dismiss on completion or remain until user closes?
- Should we show per-host success/failure list, or just overall progress?

## Implementation Steps
1. Add reusable progress popup widget in shared widgets.
2. Update Docker scan to filter out disabled hosts.
3. Replace `RemoteScanDialog` usage with progress popup.
4. (Optional) Apply to Kubernetes scan flow.

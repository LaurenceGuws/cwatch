# TODO
- Normalize tab state model (id/title/label/kind/host/context/command/metadata) into a shared base usable by Docker/Servers/K8s.
  - Ensure Kubernetes workspace persists TabState (details/resources/placeholder) and add coverage when ready.
- Align tab factories: consistent hooks (options controllers, close warnings, renameability) and workspace state registration; document for new tab types. (Documented in docs/tabs/tab_factory_guidelines.md)
- Add unit/widget tests for workspace restore/persistence and remote cache behavior to guard future K8s work.
- Adopt shared tabbed workspace shell/registry across new modules (e.g., K8s) and tidy any remaining per-view wiring.

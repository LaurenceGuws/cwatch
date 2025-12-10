Plan: consolidate SSH UX and hide backend details from UI

- Make `SshShellFactory` the sole way UI gets a `RemoteShellService`; remove all backend checks/instantiation outside `services/ssh`.
- Move passphrase/key-unlock flow into the builtin service via a single auth coordinator: on key-locked/passphrase-required, builtin shell triggers a shared prompt callback and retries internally. UI just calls shell methods.
- Remove UI downcasts to builtin classes (trash tab, ssh_auth_handler, terminal tab, resource parser). If a prompt is needed, it goes through the coordinator provided at app boot.
- Keep key config UI using `BuiltInSshKeyService` for CRUD/bindings, but runtime key status and vault/store access live only inside builtin shell/client manager.
- Optional: move backend implementations under an internal `ssh/src` namespace and stop exporting them; only expose `RemoteShellService`, `SshShellFactory`, and `BuiltInSshKeyService` (for settings).

Progress
- [x] Factory + surface scan: `SshShellFactory` now injected into HomeShell/Servers/Docker/Settings; explorer/trash tabs now require an injected shell; added `KnownHostsStore` and host verification for builtin backend; process runner now respects host key store with accept-new.
- [x] Auth flows to centralize: Added `SshAuthCoordinator` + UI prompter; Servers/Docker shells and port forwarding now use the shared coordinator; explorer `SshAuthHandler` is pass-through (no downcasts); Docker/Servers unlock dialogs removed.
- [ ] Next steps: scrub remaining UI catch/unwrap code paths so terminal tabs/resource parsers also request shells with the coordinator; consider moving backend implementations under ssh/src.

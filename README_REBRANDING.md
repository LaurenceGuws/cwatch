# Inodics

**The science of infrastructure as files.**

Inodics is an operating-system-independent desktop control plane for Linux-native environments. Built with Flutter and powered by SSH, Docker, Kubernetes, and virtual filesystem abstractions, it treats every remote system, container, and cluster as part of one unified file-centric graph  because on Linux, **everything is a file**.

---

## Product Vision

Modern infrastructure is fragmented across servers, container engines, cluster contexts, and virtualized environments. Inodics unifies them through a fundamental principle:

> **Infrastructure state, transport, and interaction can be modeled as a distributed virtual filesystem, interoperable at the inode level.**

This enables:

* cross-module resource integration (servers ” containers ” clusters)
* shared terminal and file workspaces
* seamless I/O interoperability across environments
* OS-independent clients operating on Linux-native primitives

---

## Capabilities

### Servers & SSH

* Secure SSH connectivity using built-in or system backends
* Resource monitoring panels, process tree, logs
* Remote file explorer with cached editing and intelligent synchronization
* PTY-backed terminal tabs for interactive sessions

### Docker

* Multi-engine and remote context dashboards
* Container lifecycle management
* Terminal access inside containers
* File-based interoperability with host and cluster layers

### Kubernetes

* Context and namespace dashboards
* Resource lists backed by `kubectl`
* Cluster terminal workspaces
* Unified file-centric access to cluster artifacts

### WSL (Windows only)

* Distribution views via `lib/modules/wsl/`
* Linux environment access from Windows with no abstraction penalty

### Workspace Tools

* Terminal tabs with persistence
* Remote file editor with syntax detection and theme presets
* Debug log viewer for SSH/Docker/K8s activity
* Cached explorers and editors synchronized via inode operations

---

## Architecture Philosophy

Inodics is structured as a **layered systems science stack**, where domain logic is cleanly separated from UI concerns:

* **UI** communicates only with controllers/view-models
* **Controllers** orchestrate services and trigger UI adapters for dialogs and notifications
* **Services** contain pure domain logic (no Flutter imports)
* **Repositories** encapsulate data access (filesystem, SSH, caches, configuration)
* **Adapters/UI Bridges** are the only layer touching Flutter UI APIs
* **Shared utilities** handle cross-cutting concerns
* **Global layer structure** (not nested per module):

```
lib/app/controllers/
lib/app/services/
lib/app/repositories/
lib/app/adapters/
lib/data/sources/
lib/data/models/
lib/ui/views/
lib/ui/widgets/
lib/ui/bindings/
```

---

## Code Orientation

| Path                            | Responsibility                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------------ |
| `lib/core/`                     | App bootstrap, navigation shell, workspace persistence                               |
| `lib/modules/`                  | UI modules: `servers/`, `docker/`, `kubernetes/`, `wsl/`, `debug_logs/`, `settings/` |
| `lib/services/ssh/`             | SSH backends, key vault, host verification, SFTP, PTY terminals                      |
| `lib/shared/views/shared/tabs/` | Terminal, editor, explorer tabs + shared dialogs                                     |
| `assets/`                       | Theme presets and terminal/editor media                                              |
| `packages/`                     | Patched dependencies (`xterm_patched`, `flutter_code_editor_patched`)                |

---

## Linux-First Interoperability Model

The products integration power comes from modeling remote resources using **virtual filesystem and inode-level operations**:

* Docker and Kubernetes artifacts are linked to host systems through file primitives
* SSH file explorers and container terminals share a common I/O workspace layer
* Cluster contexts and engines become addressable filesystem nodes
* Module interoperability behaves like **union mounts, linkers, and multiplexed file graphs**

---

## Installation & Usage

1. Install Flutter SDK
2. Retrieve dependencies:

   ```
   flutter pub get
   ```
3. Run the app:

   ```
   flutter run -d <device>
   ```
4. Validate changes:

   ```
   flutter analyze
   ```
5. Run tests:

   ```
   flutter test
   ```

---

## Contribution Standards

* 2-space indentation
* Trailing commas in widgets
* Ordered imports: SDK ’ third-party ’ project
* No UI logic inside services or repositories
* All cross-environment interactions should preserve file/inode-centric semantics
* `flutter analyze` must pass before commits

---

## Branding Identity

| Principle             | Expression                                                     |
| --------------------- | -------------------------------------------------------------- |
| Everything is a file  | Remote systems modeled as VFS nodes                            |
| Inodes are the truth  | Infra resources tracked and linked like filesystem metadata    |
| Integration is I/O    | Modules interoperate via streams, links, and mounts            |
| Client is universal   | Flutter UI, Linux primitives underneath                        |
| Control is structural | Designed like a system science framework, not just a dashboard |

---

## License

MIT  with a commitment to keep infrastructure interaction open, deterministic, and filesystem-native.

---

If you want, I can also generate:

* a `CHANGELOG.md` with a scientific tone
* a landing page hero section
* or logo concept directions

Indicate your next focus and I will produce it.


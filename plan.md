# Server Control App – Detailed Plan

## 1. Vision & Goals
- Provide a unified console that can discover and manage physical servers, hypervisors, virtual machines, and containers.
- Offer file-explorer-style remote browsing plus an embedded terminal for live interaction.
- Ensure modularity so that additional providers (cloud, on-prem clusters, managed services) can be plugged in without refactoring the core.
- Bake in security, auditing, and automation hooks from day one.

## 2. High-Level Architecture
| Layer | Responsibilities | Technologies / Notes |
| --- | --- | --- |
| Presentation (Flutter app) | Responsive UI, simplified workflows, offline caching, cross-platform builds | Flutter/Dart + Provider or Riverpod for state, WebSocket clients, terminal widget |
| Application Services | Session manager, command routing, orchestration workflows | Dart services backed by background isolates; gRPC/WebSocket adapters |
| Integration Connectors | Physical agent, hypervisor connector, VM connector, container connector | Implemented as modular packages; rely on platform-specific daemons |
| Remote Agents | Lightweight binaries/containers that live on managed infrastructure | Rust/Go agents with TLS mutual auth; expose gRPC endpoints |
| Data Layer | Inventory database, credential vault, logs, policies | SQLite locally for cache; remote Postgres/Redis combo; secrets via Vault/SOPS |

## 3. Modular Feature Breakdown
### 3.1 Core Platform
1. **Identity & Access**
   - OAuth2/OIDC login, MFA support, role-based permissions.
   - Audit log service capturing command history, file actions, and terminal transcripts.
2. **Inventory & Discovery**
   - CRUD for server records with tagging.
   - Agent heartbeat tracking and status dashboards.
3. **Session & Command Routing**
   - Tunnel multiplexing for file explorer, terminal, and metrics streams.
   - Automatic fallback paths (SSH, IPMI, vendor APIs).

### 3.2 Hardware Control Module
1. **Out-of-Band Management**
   - IPMI/Redfish connectors for power, sensors, BIOS toggles.
   - Workflow templates: reboot, firmware deploy, PXE boot.
2. **Rack & Power Monitoring**
   - Environmental telemetry ingest (temperature, power draw).
   - Alerting hooks (webhook, PagerDuty).

### 3.3 Virtualization Module
1. **Hypervisor Support**
   - vSphere/libvirt connectors for VM lifecycle operations.
   - Snapshot, clone, migrate actions with progress updates.
2. **VM Guest Interaction**
   - Guest agent for OS-level commands, package installs, config push.

### 3.4 Container Module
1. **Orchestrator Integrations**
   - Kubernetes/Docker connectors for pod/service lifecycle.
   - Namespace-level RBAC mapping to platform roles.
2. **Registry & Image Management**
   - Image inventory, vulnerability scan results, signing status.

### 3.5 Remote File Explorer & Terminal
1. **File Explorer**
   - Tree view with lazy loading, breadcrumb navigation, drag/drop upload/download.
   - Diff viewer for config edits, log tail streaming.
2. **Embedded Terminal**
   - PTY emulation via WebSocket streaming.
   - Session recording, command whitelists/blacklists, clipboard sync.

## 4. Cross-Cutting Concerns
- **Security:** TLS mutual auth, secrets rotation, per-action approvals, Just-In-Time credentials.
- **Observability:** Structured logging, OpenTelemetry traces, metrics dashboards.
- **Offline/Edge Support:** Local agent caching, queued commands when connectivity drops.
- **Extensibility:** Plugin SDK for new connectors; versioned APIs and compatibility tests.

## 5. Milestones & Deliverables
1. **MVP (Weeks 1–6)**
   - Flutter shell app with auth, dashboard, server list.
   - Remote agent prototype supporting SSH commands.
   - Terminal + basic file explorer (list/download/upload).
2. **Hardware Module Beta (Weeks 7–12)**
   - Implement IPMI/Redfish workflows.
   - Sensor telemetry streaming and alert rules.
3. **Virtualization Module (Weeks 13–18)**
   - Hypervisor discovery, VM lifecycle controls, snapshots.
4. **Container Module (Weeks 19–24)**
   - Kubernetes integration, pod console, log streaming.
5. **Polish & Hardening (Weeks 25–30)**
   - RBAC refinements, audit exports, plugin SDK preview, integration tests.

## 6. Testing Strategy
- Unit tests per connector and service.
- Contract tests between app and agents (gRPC + WebSocket).
- Scenario tests for workflows (provision, reboot, deploy container).
- Load tests for concurrent sessions, file transfers, and terminal streams.

## 7. Deployment & Ops
- **Agents:** Delivered as container images or systemd services, auto-update channel.
- **Backend Services:** Deployable via Helm charts or Terraform modules.
- **Desktop/Web App:** CI pipelines for Flutter builds, artifact signing, auto-update feed.

## 8. Next Steps
1. Validate requirements with stakeholders, prioritize modules.
2. Define API contracts + SDK skeleton.
3. Build proof-of-concept agent and Flutter client skeleton.
4. Establish CI/CD pipeline and observability stack.

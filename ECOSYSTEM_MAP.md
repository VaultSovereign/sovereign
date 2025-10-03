# 🏛️ VaultMesh Ecosystem Map

**Last Updated:** October 3, 2025  
**Purpose:** High-level overview of all repositories and their relationships

---

## 📊 Repository Statistics

| Repo | Files | Commits | Status | Primary Tech |
|------|-------|---------|--------|--------------|
| **VaultMesh** | 424 | 62 | 🟡 Active dev | Rust + TypeScript |
| **forge** | 726 | 122 | 🟢 Production | TypeScript + Node.js |
| **infra-dns** | 28 | 3 | 🟢 Launch ready | Terraform + Cloudflare |
| **infra-servers** | 4 | 1 | 🔵 Scaffold | Ansible + Ubuntu |
| **meta** | 60 | 1 | 🟢 Stable | TypeScript + Google AI |
| **ops** | 91 | 8 | 🟢 Stable | YAML prompts + schemas |
| **sovereign** | 34 | 4 | 🟢 Production | Bash + GCP Workstations |

**Total ecosystem:** 1,367 files across 7 repositories

---

## 🌀 The Five Pillars (from Mandala)

```
                    🏛️ Polis Core
                  (VaultMesh Ledger)
                         │
        ┌────────────────┼────────────────┐
        │                │                │
    Deployment       Guardian         Alerting
     (forge)       (sovereign)         (ops)
        │                │                │
        └────────────────┼────────────────┘
                         │
                ┌────────┴────────┐
            Covenant          Evolution
           (Governance)     (Alchemical)
```

---

## 📦 Repository Deep Dive

### 1️⃣ **VaultMesh** - The Core Service
**GitHub:** `VaultSovereign/VaultMesh`  
**Branch:** `sync/default-into-main-20251002T171618Z`

**Purpose:** Rust backend service + web portal for AI prompt orchestration

**Key Components:**
- `src/` - Rust core service
- `portal/` - Web interface
- `scripts/` - CI/CD automation
- `catalog/` - Prompt catalog (NEW: audit tools)
- `schemas/` - JSON schemas (NEW: audit.scroll.v1.json)
- `tests/` - Test suite

**Recent Work:**
- ✅ Audit tooling with BLAKE3 checksums
- ✅ CI status checking improvements
- ✅ Codebase audit catalog

**Status:** Active development, needs merge to main

---

### 2️⃣ **forge** - Agent Orchestration & Deployment
**GitHub:** `VaultSovereign/forge`  
**Branch:** `fix/verify-event-bff-dts-gh-issues`

**Purpose:** TypeScript agent system + GCP Cloud Run deployment infrastructure

**Key Components:**
- `agents/` - AI agent implementations
- `dispatcher/` - Request routing
- `workbench/` - BFF + frontend
- `ai-companion-proxy-starter/` - Proxy service (NEW!)
- `infra/gcp/` - Terraform for Cloud Run
- `docs/` - Sacred texts library

**Sacred Texts:**
- 📜 `CIVILIZATION_COVENANT.md` - Living constitution
- 🌀 `VaultMesh_Mandala.svg` - Interactive architecture
- 🜞 `RECEIPTS.md` - Receipt schema & Merkle rollup
- 🜏 `GUARDIAN_ALERTING.md` - Slack alerting

**Recent Work:**
- ✅ Civilization Covenant added
- ✅ Mandala architecture visualization
- ✅ Guardian drill system with receipts
- ✅ AI companion proxy starter
- ✅ Risk operations (risk_policy_gate, risk_register)
- ✅ Gemini dispatch workflows

**Status:** Heavy active development, production-ready

---

### 3️⃣ **infra-dns** - Network Foundation
**GitHub:** `VaultSovereign/infra-dns`  
**Branch:** `main`

**Purpose:** Terraform-managed Cloudflare DNS for vaultmesh.org + vaultmesh.cloud

**Key Components:**
- `org.tf` - vaultmesh.org records
- `cloud.tf` - vaultmesh.cloud records
- `dns-cutover.sh` - Migration script
- `guard-spf.sh` - SPF validation
- Launch documentation (NEW!)

**Domains Managed:**
- `vaultmesh.org` - Main domain (Google Workspace, blog, community)
- `vaultmesh.cloud` - Service zone (API, ops, monitoring)

**Recent Work:**
- ✅ Complete launch documentation
- ✅ CUTOVER, PRE-FLIGHT, LAUNCH-READY guides
- ✅ DNS cutover receipt

**Status:** 🚀 LAUNCH READY

---

### 4️⃣ **infra-servers** - Physical Infrastructure
**GitHub:** `VaultSovereign/infra-servers`  
**Branch:** `main`

**Purpose:** Ansible automation for server provisioning (blog, forum, monitoring, CI)

**Planned Servers:**
- `blog.vaultmesh.org` - Next.js/Hugo + Caddy
- `polis.vaultmesh.org` - Discourse/Lemmy forum
- `mon.vaultmesh.cloud` - Grafana + Prometheus
- `ci.vaultmesh.cloud` - GitHub Actions runner

**Key Components:**
- `ansible.cfg` - Ansible settings
- `inventory.ini.example` - Server definitions
- `group_vars/all.yml` - Global config

**Status:** 📝 Scaffold only - needs playbooks and roles

---

### 5️⃣ **meta** - Content Publishing
**GitHub:** `VaultSovereign/meta`  
**Branch:** `main`

**Purpose:** Google AI integration for cybersecurity content automation

**Key Features:**
- Gemini/Vertex AI integration
- Blogger API
- Google Drive/Docs/Sheets
- Fourth gate (community channels)

**Status:** 🟢 Stable, production ready

---

### 6️⃣ **ops** - Governance Library
**GitHub:** `VaultSovereign/ops`  
**Branch:** `main`

**Purpose:** Civilization-as-code governance + 16 production-ready cybersecurity prompts

**Key Components:**
- 16 production prompts (reconnaissance, vulnerability analysis, incident response)
- Safety classifications (read-only, advisory, lab-only)
- DAO governance primitives
- Adversarial testing framework

**Governance Drafts:**
- `SIGNALS.md` - Weighted signaling
- `FEDERATION.md` - Membership & trust
- `LEADERSHIP.md` - Roles & selection
- `CRISIS.md` - Emergency protocols

**Status:** 🟢 Stable library, governance framework in progress

---

### 7️⃣ **sovereign** - Development Workstation
**GitHub:** `VaultSovereign/sovereign`  
**Branch:** `main`

**Purpose:** Declarative Google Cloud Workstation with guardian drills

**Key Components:**
- `workstation/` - Config, startup scripts, drill receipts
- `gcloud/` - GCP provisioning scripts
- `local/` - Local machine bootstrap
- Guardian drill system (60s health checks)

**Security Model:**
- ADC-first (no static keys)
- Least-privilege service accounts
- Daily Merkle root generation
- Cryptographic receipts

**Status:** 🟢 Production, your current environment!

---

## 🔗 Repository Dependencies

```
                VaultMesh (Core)
                      ↓
                   forge
                  ↙  ↓  ↘
         infra-dns  ops  meta
              ↓           ↓
        infra-servers  (publishing)
              ↓
         sovereign (dev env)
```

**Dependency Flow:**
1. **VaultMesh** → Core Rust service
2. **forge** → Orchestrates VaultMesh + deploys to GCP
3. **infra-dns** → Provides network layer for all services
4. **infra-servers** → Physical servers for blog/forum/monitoring
5. **ops** → Governance + prompt library used by VaultMesh
6. **meta** → Publishing system for content
7. **sovereign** → Dev environment to build everything

---

## 🎯 Current Focus Areas

### 🔥 High Priority
1. **VaultMesh** - Merge audit tooling to main
2. **forge** - Merge covenant + proxy to main
3. **infra-dns** - Execute DNS cutover (LAUNCH!)

### 🟡 Medium Priority
4. **infra-servers** - Build Ansible playbooks
5. **ops** - Complete governance framework

### 🟢 Stable
6. **meta** - Stable, no immediate work
7. **sovereign** - Stable, working great

---

## 📈 Growth Trajectory

- **Phase 1 (Complete):** Core infrastructure
  - ✅ VaultMesh service
  - ✅ sovereign workstation
  - ✅ DNS management

- **Phase 2 (In Progress):** Orchestration & Deployment
  - 🔄 forge agent system
  - 🔄 Guardian drills
  - 🔄 Cloud Run deployment

- **Phase 3 (Next):** Physical Infrastructure
  - 📝 Ansible server automation
  - 📝 Blog deployment
  - 📝 Community forum (Polis)
  - 📝 Monitoring stack

- **Phase 4 (Future):** Governance & Scale
  - 📝 DAO primitives
  - 📝 Federation
  - 📝 Leadership selection
  - 📝 Crisis protocols

---

## 🧭 Navigation Tips

**When working on:**
- **Backend/Core** → `VaultMesh/`
- **Agents/Deployment** → `forge/`
- **DNS/Network** → `infra-dns/`
- **Servers** → `infra-servers/`
- **Content** → `meta/`
- **Governance** → `ops/`
- **Dev Environment** → `sovereign/`

**Key Documents:**
- Architecture: `forge/docs/VaultMesh_Mandala.svg`
- Constitution: `forge/docs/CIVILIZATION_COVENANT.md`
- Operations: `ops/README.md`
- Security: `sovereign/docs/SECURITY.md`

---

## 🔥 The Mission

**Build Earth's Library of Alexandria that can't burn.**

A permanent, distributed, cryptographically-verified repository of human knowledge and coordination infrastructure.

**Steel sung. Ledger sealed. Polis eternal.** ⚔️

---

*This document is a living map. Update as the ecosystem grows.*

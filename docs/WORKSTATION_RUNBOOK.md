# Workstation Runbook

**Sovereign Workstation deployment guide for VaultMesh operators.**

This runbook walks you through the complete lifecycle: authentication → IAM bootstrap → workstation creation → daily verification.

---

## Prerequisites

### Required Tools
- **gcloud CLI** - Google Cloud SDK
- **yq** - YAML processor (`snap install yq` or `brew install yq`)
- **jq** - JSON processor
- **make** - GNU Make
- **git** - Version control

### Optional (for drills)
- **b3sum** - BLAKE3 hashing for Merkle roots

### Access Requirements
- Google Cloud account with project owner/admin role
- GitHub access to `VaultSovereign/sovereign`
- Billing account linked to GCP project

---

## Step 0: Initial Setup

### Clone the repository

```bash
git clone git@github.com:VaultSovereign/sovereign.git
cd sovereign
```

### Configure environment

```bash
cp .env.example .env
nano .env  # or your preferred editor
```

**Required variables:**
```bash
PROJECT_ID=vaultmesh-473618              # Your GCP project
REGION=europe-west1                       # Primary region
WORKSTATION_CONFIG=sovereign-config       # Config name
WORKSTATION_CLUSTER=sovereign-cluster     # Cluster name
WORKSTATION_ID=sovereign-dev              # Workstation ID
DEPLOYER_SA=vaultmesh-deployer           # Deployer service account
PROXY_SA=ai-companion-proxy              # Proxy service account
PUBLISHER_SA=meta-publisher              # Publisher service account
SCHEDULER_SA=scheduler                   # Scheduler service account
CF_API_TOKEN=                            # Optional: Cloudflare API token
```

### Authenticate with Google Cloud

```bash
# User account authentication
gcloud auth login

# Application Default Credentials (ADC) - critical for workstations
gcloud auth application-default login

# Set project
gcloud config set project $PROJECT_ID

# Verify ADC is working
gcloud auth application-default print-access-token > /dev/null && echo "✓ ADC working"
```

**Why ADC matters:**
- No JSON keyfiles to manage or rotate
- All tools (gcloud, Terraform, SDKs) auto-use your identity
- Workstation inherits service account identity via metadata server
- Zero-trust security model

---

## Step 1: Bootstrap IAM

Create the service accounts and bind minimal required permissions.

```bash
make gcloud:iam
```

### What this does:

**Creates 4 service accounts:**
1. **vaultmesh-deployer** - Workstation runtime identity
   - `roles/run.admin` - Deploy Cloud Run services
   - `roles/iam.serviceAccountUser` - Act as other SAs
   - `roles/iam.serviceAccountTokenCreator` - Generate tokens

2. **ai-companion-proxy** - AI companion runtime
   - `roles/iam.serviceAccountTokenCreator` - Minimal token creation

3. **meta-publisher** - Meta/documentation publisher
   - (Add specific roles as needed)

4. **scheduler** - Scheduled task runner
   - (Add specific roles as needed)

### Verify

```bash
gcloud iam service-accounts list
```

You should see all 4 SAs created.

### Troubleshooting

**Error: "already exists"**
- Script is idempotent; this is expected on re-runs

**Error: "Permission denied"**
- Ensure you have `roles/owner` or `roles/iam.serviceAccountAdmin` on the project

---

## Step 2: Create Workstation Config

Generate the workstation configuration from `workstation/config.yaml`.

```bash
make gcloud:config
```

### What this does:

1. **Enables Cloud Workstations API**
   ```bash
   gcloud services enable workstations.googleapis.com
   ```

2. **Creates workstation cluster** (if not exists)
   - Network: `default`
   - Subnetwork: `default`
   - Region: `$REGION`

3. **Creates workstation config** from YAML
   - Machine type: `standard-4` (4 vCPU)
   - Memory: 16 GB
   - Persistent disk: 200 GB (BALANCED)
   - Service account: `vaultmesh-deployer`
   - Base image: `gcr.io/cloud-workstations-images/base:latest`

### Configuration anatomy

The config is derived from `workstation/config.yaml`:

```yaml
machine:
  cpu: 4                    # Standard-4 machine type
  memory_gb: 16            # RAM allocation
  disk_gb: 200             # Persistent disk size
  disk_type: BALANCED      # BALANCED | PERFORMANCE
  ephemeral: false         # Keep disk between sessions

service_account: ${DEPLOYER_SA}@${PROJECT_ID}.iam.gserviceaccount.com

labels:
  app: sovereign
  owner: vault
  purpose: dev
```

### Verify

```bash
# List clusters
gcloud workstations clusters list --region=$REGION

# List configs
gcloud workstations configs list \
  --cluster=$WORKSTATION_CLUSTER \
  --region=$REGION
```

### Troubleshooting

**Error: "yq: command not found"**
```bash
# Ubuntu/Debian
sudo snap install yq

# macOS
brew install yq
```

**Error: "Cluster creation timed out"**
- Cluster creation is async; wait 5-10 minutes and re-run
- Check status: `gcloud workstations clusters describe ...`

---

## Step 3: Create Workstation Instance

Spin up your actual development workstation.

```bash
make gcloud:workstation
```

### What this does:

1. **Creates workstation instance**
   ```bash
   gcloud workstations workstations create $WORKSTATION_ID \
     --cluster=$WORKSTATION_CLUSTER \
     --config=$WORKSTATION_CONFIG \
     --region=$REGION
   ```

2. **Retrieves access URL**
   - Outputs browser URL to access workstation
   - Example: `https://xxxxx.workstations.dev`

### Access your workstation

1. Copy the URL from the command output
2. Open in browser
3. Workstation boots and runs `startup.sh`:
   - System updates (apt-get update)
   - Node.js + pnpm via nvm
   - Rust toolchain
   - Python + pipx
   - tmux + zsh
   - gcloud config setup

4. On every boot, `poststart.sh` runs:
   - Syncs dotfiles from GitHub
   - Exports pnpm to PATH
   - Displays MOTD

### Verify

```bash
# List workstations
gcloud workstations workstations list \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION

# Get workstation details
gcloud workstations workstations describe $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION
```

### Working with the workstation

**Start workstation:**
```bash
gcloud workstations workstations start $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION
```

**Stop workstation:**
```bash
gcloud workstations workstations stop $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION
```

**Delete workstation:**
```bash
make gcloud:delete  # or use gcloud/delete-workstation.sh
```

### Troubleshooting

**Error: "Config not found"**
- Run `make gcloud:config` first

**Workstation stuck in "STARTING"**
- First boot takes 5-10 minutes while startup.sh runs
- Check logs in Cloud Console

---

## Step 4: Run Guardian Drill

Verify workstation health and generate cryptographic receipts.

```bash
make drill
```

### What this does:

**Checks performed:**
1. ✓ gcloud project configured
2. ✓ Application Default Credentials working
3. ✓ pnpm installed and in PATH
4. ✓ Rust/cargo installed
5. ✓ Cloudflare API token set (optional)

**Output:**
- `workstation/receipts/drill-<timestamp>.json` - Individual receipt
- `workstation/receipts/root-<date>.json` - Daily Merkle root

### Receipt structure

```json
{
  "kind": "vaultmesh.workstation.guardian_drill.v1",
  "ts": "20251003T143022Z",
  "project": "vaultmesh-473618",
  "region": "europe-west1",
  "checks": [
    {"check": "gcloud-project", "ok": true},
    {"check": "adc", "ok": true},
    {"check": "pnpm", "ok": true},
    {"check": "rust", "ok": true},
    {"check": "cf-token", "ok": false}
  ]
}
```

### Merkle root

Daily receipts are hashed with BLAKE3 to produce a single root:

```json
{
  "day": "2025-10-03",
  "root": "abc123...def789"
}
```

This provides cryptographic proof that:
- All drills for the day passed
- Receipt chain is unbroken
- Workstation configuration is consistent

### Daily ritual

**Run drill every 24 hours:**
```bash
# Option 1: Manual
make drill

# Option 2: Add to crontab (inside workstation)
0 9 * * * cd /workspace/sovereign && make drill

# Option 3: Cloud Scheduler (advanced)
# See docs/CLOUD_SCHEDULER.md
```

### Verify receipts

```bash
# List all receipts
ls -lh workstation/receipts/

# View latest drill
jq . workstation/receipts/drill-*.json | tail -100

# View Merkle roots
cat workstation/receipts/root-*.json
```

### Troubleshooting

**Error: "b3sum: command not found"**
- Drill still works; just skips Merkle root generation
- Install: `cargo install b3sum` or download from BLAKE3 releases

**Check fails: "adc"**
- Re-run: `gcloud auth application-default login`
- Verify: `gcloud auth application-default print-access-token`

**Check fails: "cf-token"**
- Optional check; safe to ignore if not using Cloudflare
- Set `CF_API_TOKEN` in `.env` if needed

---

## Maintenance

### Update workstation config

1. Edit `workstation/config.yaml`
2. Re-run: `make gcloud:config`
3. Recreate workstation: `make gcloud:delete && make gcloud:workstation`

### Update IAM permissions

1. Edit `gcloud/iam-bootstrap.sh`
2. Re-run: `make gcloud:iam`

### Upgrade tools (inside workstation)

```bash
# Node.js
nvm install 20 && nvm use 20

# Rust
rustup update

# pnpm
pnpm add -g pnpm

# gcloud
gcloud components update
```

### Backup receipts

Receipts are **gitignored** by default (contain operational secrets).

**To preserve:**
```bash
# Option 1: Local backup
tar -czf receipts-$(date +%F).tar.gz workstation/receipts/

# Option 2: Cloud Storage
gsutil cp -r workstation/receipts/ gs://$PROJECT_ID-receipts/

# Option 3: Encrypted git
git-crypt init
git-crypt add-gpg-user your-key@example.com
# Remove receipts from .gitignore
git add workstation/receipts/ && git commit
```

---

## Architecture

### Security Model

```
┌─────────────────────────────────────────┐
│  Guardian (guardian@vaultmesh.org)      │
│  ├─ gcloud auth login                   │
│  └─ gcloud auth application-default     │
└─────────────────┬───────────────────────┘
                  │ ADC
                  ▼
┌─────────────────────────────────────────┐
│  Workstation (sovereign-dev)            │
│  Service Account: vaultmesh-deployer    │
│  ├─ roles/run.admin                     │
│  ├─ roles/iam.serviceAccountUser        │
│  └─ roles/iam.serviceAccountTokenCreator│
└─────────────────┬───────────────────────┘
                  │ Impersonation
                  ▼
┌─────────────────────────────────────────┐
│  Runtime Services                       │
│  ├─ ai-companion-proxy                  │
│  ├─ meta-publisher                      │
│  └─ scheduler                           │
└─────────────────────────────────────────┘
```

### Network Flow

```
Browser → Cloud Workstations URL
       ↓
   Workstation (VPC: default)
       ↓
   Google APIs (via Private Google Access)
       ↓
   Cloud Run / GCS / Vertex AI
```

### Identity Chain

1. **Human operator** (guardian@vaultmesh.org)
   - Initial auth via `gcloud auth login`
   - Sets up ADC for local tools

2. **Workstation instance** (sovereign-dev)
   - Runs as `vaultmesh-deployer` service account
   - Inherits identity from GCE metadata server
   - No keyfiles on disk

3. **Deployed services** (Cloud Run, etc.)
   - Run as specialized SAs (proxy, publisher, scheduler)
   - Workstation can impersonate via `serviceAccountUser` role

### Receipt Flow

```
Guardian Drill (make drill)
  ↓
Check: gcloud, ADC, tools
  ↓
Generate receipt JSON
  ↓
Hash with BLAKE3 (b3sum)
  ↓
Append to daily Merkle tree
  ↓
Store: workstation/receipts/
```

---

## Reference

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PROJECT_ID` | GCP project ID | `vaultmesh-473618` |
| `REGION` | Primary region | `europe-west1` |
| `WORKSTATION_CONFIG` | Config name | `sovereign-config` |
| `WORKSTATION_CLUSTER` | Cluster name | `sovereign-cluster` |
| `WORKSTATION_ID` | Instance ID | `sovereign-dev` |
| `DEPLOYER_SA` | Deployer SA name | `vaultmesh-deployer` |
| `PROXY_SA` | Proxy SA name | `ai-companion-proxy` |
| `PUBLISHER_SA` | Publisher SA name | `meta-publisher` |
| `SCHEDULER_SA` | Scheduler SA name | `scheduler` |
| `CF_API_TOKEN` | Cloudflare token | (optional) |

### Make Targets

| Target | Description |
|--------|-------------|
| `make gcloud:iam` | Bootstrap IAM (create SAs) |
| `make gcloud:config` | Create workstation config |
| `make gcloud:workstation` | Create workstation instance |
| `make drill` | Run guardian drill |
| `make local` | Bootstrap local machine |

### Service Accounts

| SA | Email | Purpose | Roles |
|----|-------|---------|-------|
| Deployer | `vaultmesh-deployer@PROJECT.iam` | Workstation runtime | `run.admin`, `iam.serviceAccountUser`, `iam.serviceAccountTokenCreator` |
| Proxy | `ai-companion-proxy@PROJECT.iam` | AI companion proxy | `iam.serviceAccountTokenCreator` |
| Publisher | `meta-publisher@PROJECT.iam` | Meta publisher | (custom) |
| Scheduler | `scheduler@PROJECT.iam` | Scheduled tasks | (custom) |

### File Structure

```
sovereign/
├── README.md                    # Project overview
├── Makefile                     # Automation targets
├── .env                         # Environment config (gitignored)
├── .env.example                 # Template
├── workstation/
│   ├── config.yaml              # Machine/SA config
│   ├── startup.sh               # First boot script
│   ├── poststart.sh             # Every boot script
│   ├── drills/
│   │   └── guardian-drill.sh    # Health check
│   └── receipts/                # Drill outputs (gitignored)
├── gcloud/
│   ├── iam-bootstrap.sh         # Create SAs
│   ├── create-config.sh         # Create config
│   ├── create-workstation.sh    # Create instance
│   └── delete-workstation.sh    # Cleanup
├── local/
│   ├── install.sh               # Local bootstrap
│   └── dotfiles/                # Shell configs
├── devcontainer/
│   ├── devcontainer.json        # VS Code container
│   └── Dockerfile               # Container image
└── docs/
    └── WORKSTATION_RUNBOOK.md   # This file
```

---

## Support

**Issues:** https://github.com/VaultSovereign/sovereign/issues  
**Docs:** https://github.com/VaultSovereign/sovereign  
**Contact:** guardian@vaultmesh.org

---

**Last updated:** 2025-10-03  
**Version:** 1.0.0  
**Maintained by:** VaultMesh Guardian

# Sovereign Workstation

Declarative workstation for VaultMesh dev:
- **Google Cloud Workstations** (ADC first, least-privilege SAs)
- **Local bootstrap** (macOS/Linux)
- **Daily guardian drill** with receipts + Merkle root
- **DevContainer support** for symmetric dev environments

## Quick start (Cloud Workstations)

```bash
cp .env.example .env && nano .env        # fill PROJECT_ID, REGION, SA names
make gcloud:iam                          # create/verify SAs + roles
make gcloud:config                       # create Workstation config from YAML
make gcloud:workstation                  # create a new workstation
# open the URL printed by gcloud, workspace starts with startup.sh
```

## Local Development

Bootstrap your local macOS/Linux machine with all required tools:

```bash
./local/install.sh
```

## Guardian Drill

Run the guardian drill to verify workstation health and configuration:

```bash
make drill
```

This generates:
- `workstation/receipts/drill-<timestamp>.json` - Individual drill receipt
- `workstation/receipts/root-<date>.json` - Daily Merkle root of all receipts

## DevContainer

Open this repository in VS Code with the Remote-Containers extension to get a fully configured development environment that mirrors the Cloud Workstation setup.

## Architecture

```
workstation/
  config.yaml              # Single source of truth (region, SA, size, disk, labels)
  startup.sh               # Runs on first boot (installs tools)
  poststart.sh             # Runs every boot (pulls dotfiles, sets secrets)
  receipts/                # Drill receipts + merkle roots
  drills/guardian-drill.sh # Verifies ADC, gcloud, CloudFlare, meta
  
gcloud/
  create-config.sh         # gcloud CLI → Workstation Config
  create-workstation.sh    # gcloud CLI → Workstation from config
  delete-workstation.sh    # Cleanup
  iam-bootstrap.sh         # SAs/roles bindings you need
  
local/
  install.sh               # Bootstrap mac/linux laptop
  dotfiles/                # wezterm, zsh, tmux, gitconfig, vscode settings (minimal)
  
devcontainer/
  devcontainer.json        # Symmetric dev env for Codespaces/Container
  Dockerfile               # Base image with all tools
```

## Service Accounts

The workstation uses least-privilege service accounts:

- **vaultmesh-deployer** - Workstation runtime SA (Cloud Run admin, SA user/token creator)
- **ai-companion-proxy** - AI companion proxy runtime (token creator only)
- **meta-publisher** - Meta publishing service
- **scheduler** - Scheduled task runner

## Prerequisites

- **Google Cloud SDK** (`gcloud`)
- **yq** - YAML processor (`snap install yq` or `brew install yq`)
- **jq** - JSON processor
- **b3sum** - BLAKE3 hashing for Merkle roots (optional, for drills)

## Configuration

All configuration is centralized in `workstation/config.yaml` and `.env`:

- Machine specs (CPU, memory, disk)
- Service account bindings
- Region and cluster settings
- Labels and metadata

## Security Features

- **Application Default Credentials (ADC)** - No key files, identity-based auth
- **Least-privilege SAs** - Each service has minimal required permissions
- **Daily verification** - Guardian drill ensures proper configuration
- **Receipt trail** - Merkle-rooted audit log of workstation health
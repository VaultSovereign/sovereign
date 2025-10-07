# Sovereign Workstation

Declarative workstation for VaultMesh dev:
- **Google Cloud Workstations** (ADC first, least-privilege SAs)
- **Local bootstrap** (macOS/Linux)
- **Daily guardian drill** with receipts + Merkle root
- **DevContainer support** for symmetric dev environments

## Quick start (Cloud Workstations)

```bash
cp .env.example .env && nano .env        # fill PROJECT_ID, REGION, SA names
make gcloud-iam                          # create/verify SAs + roles
make gcloud-config                       # create Workstation config from YAML
make gcloud-workstation                  # create a new workstation
# open the URL printed by gcloud, workspace starts with startup.sh
```

### Workstations
- `make gcloud-config` – create/ensure cluster+config
- `make gcloud-workstation` – create/start workstation
- `make gcloud-workstation-open` – print the access URL (no create/start)
- `make gcloud-workstation-delete` – stop (default) and delete the workstation
- `make gcloud-preflight` – verify ADC, APIs, region reachability, quotas, and (optionally) network
- `make gcloud-preflight-receipt` – same as preflight, but also writes a JSON receipt to `workstation/receipts/`
  Receipts for other steps (opt-in):
  - `RECEIPT=true make gcloud-config` (or `make gcloud-config-receipt`)
  - `RECEIPT=true make gcloud-workstation` (or `make gcloud-workstation-receipt`)
  - `RECEIPT=true make gcloud-workstation-delete` (or `make gcloud-workstation-delete-receipt`)

#### Env overrides
- `PROJECT_ID`, `REGION` (default `europe-west3`), `WORKSTATION_CONFIG`/`CONFIG_ID`, `WORKSTATION_CLUSTER`/`CLUSTER_ID`, `WORKSTATION_ID`
- Delete behavior: `STOP_FIRST=true|false` (default true), `FORCE=true|false` (default false)
- Preflight: `AUTO_ENABLE=true|false` (default false), `NETWORK`, `SUBNETWORK`
- Receipts: `RECEIPT=true` (Make target already sets this), `RECEIPTS_DIR` (default `workstation/receipts`)

### Ledger
- `make ledger-compact` – canonicalize receipts (JCS), hash with domain separation, emit daily roots + proofs, and prune older receipts per day (default KEEP=5).
  Env: `RECEIPTS_DIR`, `DAILY_DIR`, `PROOFS_DIR`, `KEEP`, `LEDGER_HASH=blake3|sha256` (default `blake3`), `LEDGER_DOMAIN_VERSION` (default `1`), `FORCE=true|false` (allow pruning without proofs), `VERBOSE`.
- `make ledger-compact-dryrun` – show exactly which receipts would be kept/pruned and the resulting root(s), but perform no writes/deletes.
  Env: `KEEP`, `VERBOSE=true|false` (default true), plus `RECEIPTS_DIR`/`DAILY_DIR`/`PROOFS_DIR`, `LEDGER_HASH` (for parity checks).
- `make ledger-verify` – recompute and verify stored daily roots, inclusion proofs, and canonical receipts.
  Env: `RECEIPTS_DIR`, `DAILY_DIR`, `PROOFS_DIR`, `DAY=YYYYMMDD` (optional single-day), `STRICT=true|false` (fail if any listed file missing; default false), `LEDGER_HASH` (defaults to metadata algorithm), `LEDGER_DOMAIN_VERSION` (default `1`).
  Legacy fixtures (optional):
  ```bash
  if compgen -G "workstation/receipts/fixtures/legacy/*/*.json" >/dev/null; then
    RECEIPTS_DIR=workstation/receipts/fixtures/legacy STRICT=true make ledger-verify
  fi
  ```
- `make ledger-selftest` – run the covenant script (modern verification + domain/proof invariants; legacy verify only if fixtures exist).
  Env: inherits `KEEP`, `VERBOSE`, `LEDGER_DOMAIN_VERSION`, `SELFTEST_PROOFS`, `RECEIPTS_DIR`, `DAILY_DIR`, `PROOFS_DIR`.

Daily roots are written to `workstation/receipts/daily/<YYYYMMDD>.json` with Merkle metadata (schema v1.1) including `domain_version` for future rotations. When receipts are pruned, inclusion proofs and the canonical JCS payload are stored under `workstation/receipts/daily/proofs/<day>/<leaf_hash>.json`. These artifacts are validated by `ledger-verify` and the receipt validator (`scripts/receipt-validate.sh`).

### Maintenance (one command)
- `make ledger-maintain-preview` – plan-only: compact (dry-run), verify, and fix-all preview (with its own receipt).  
  Env passthrough: `KEEP`, `VERBOSE`, `INCLUDE`, `EXCLUDE`, `NON_VENDOR_ONLY`, `JOBS`, `SEARCH_ROOT`
- `make ledger-maintain` – apply: compact, verify, and fix-all apply (writes).  
- Ledger options:  
  - `make ledger-maintain-preview-receipt` – preview + top-level maintenance receipt  
  - `make ledger-maintain-receipt` – apply + top-level maintenance receipt
- Strict / CI helpers:
  - `make ledger-maintain-preview-strict` (or `STRICT=true make ledger-maintain-preview`) to fail fast when verify mismatches.
  - `make ledger-maintain-strict` for the apply path, and `make ci-ledger` for the full covenant bundle (validate → dry-run compact → modern verify → optional legacy verify → selftest).

### Find & fix a bug (single file)
- `make find-bug FILE=path/to/@filename` – runs a heuristic linter/auto-fixer and prints a focused diff.
  - List matches: `make find-bug-list FILE=@name`
  - Choose match: `make find-bug-choose FILE=@name` (uses `fzf` if available; respects `CHOOSE_DEFAULT`)
  - Env: `NON_VENDOR_ONLY=true|false` (default true)

### Fix many files (bulk)
- `make fix-all` – run the heuristic fixer across a set of files and print a summary table.
  Env:
  - `INCLUDE` – space-separated globs (e.g., "**/*.sh **/*.ts"). If empty, defaults to common types (`*.sh,*.ts,*.js,*.json,*.yaml,*.md,*.rs`).
  - `EXCLUDE` – space-separated globs to skip (e.g., "**/generated/** **/*.min.js").
  - `NON_VENDOR_ONLY=true|false` (default true) skips `node_modules/`, `vendor/`, `dist/`, `build/`.
  - `JOBS` – parallel workers (default: CPU count).
  - `SEARCH_ROOT` – base for non-git repos (default `.`).
- `make fix-all-dry` – same as above but no writes; shows summary of would-be changes.
  Supports: `*.sh` (shellcheck/shfmt), `*.ts/js` (eslint/prettier/tsc via pnpm), `*.json` (jq), `*.yaml` (yq), `*.rs` (cargo fmt), `*.md` (prettier).
  - Ledger options:
    - `make fix-all-preview-receipt` – dry-run (no writes) and emit `workstation/receipts/fixall-<ts>.json` (`mode:"dry-run"`).
    - `make fix-all-receipt` – apply fixes and emit a receipt (`mode:"apply"`).

#### Examples

- Preview, no writes:
  ```bash
  NON_VENDOR_ONLY=true INCLUDE="**/*.sh **/*.ts" EXCLUDE="**/dist/** **/build/**" make fix-all-dry
  ```

- Run fixes in parallel:
  ```bash
  JOBS=8 INCLUDE="**/*.sh **/*.ts **/*.md" make fix-all
  ```

- Focus only on shell scripts:
  ```bash
  INCLUDE="**/*.sh" make fix-all
  ```

### CI & Local Hooks

- GitHub Actions workflows:
  - `.github/workflows/ledger.yml` runs `make ci-ledger` (including the covenant self-test) on push/PR touching ledger-critical paths.
  - `.github/workflows/ledger-ci.yml` keeps the legacy strict preview + receipt validation for broader pushes.
- Local guard: link `githooks/pre-commit` into `.git/hooks/pre-commit` to run the same ritual before every commit.

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
- Preview with receipt (no writes):
  ```bash
  NON_VENDOR_ONLY=true INCLUDE="**/*.sh **/*.ts" EXCLUDE="**/dist/** **/build/**" make fix-all-preview-receipt
  ```

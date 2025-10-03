# ⚔️ Sovereign Workstation — Operator Checklist

**Quick reference card for workstation deployment and daily operations.**

---

## 🚀 Bootstrap (One-Time Setup)

```bash
# 1. Auth
gcloud auth login
gcloud auth application-default login

# 1.5 Preflight (optional but recommended)
make gcloud-preflight           # add AUTO_ENABLE=true to auto-enable missing APIs

# 2. IAM
make gcloud-iam

# 3. Config
make gcloud-config

# 4. Workstation
make gcloud-workstation

# 5. Drill
make drill

# Ledger (optional)
make gcloud-preflight-receipt
# or:
# RECEIPT=true make gcloud-config
# RECEIPT=true make gcloud-workstation
# RECEIPT=true make gcloud-workstation-delete
```

- Ledger: run `make gcloud-preflight-receipt` to emit `workstation/receipts/preflight-<ts>.json`.

---

## 🔑 Daily Ritual

```bash
1. Open workstation (browser URL or gcloud CLI)
2. Sync repos (git pull)
3. make drill
4. git add workstation/receipts && git commit -m "drill receipts $(date +%F)"
5. git push
```

---

## 📜 Daily Ledger Ritual

- Preview:
  - `make ledger-compact-dryrun`
  - `make ledger-verify`
  - `make fix-all-preview-receipt`

- Apply:
  - `make ledger-compact`
  - `make ledger-verify`
  - `make fix-all-receipt`

💡 **One command:**  
- Preview: `make ledger-maintain-preview` (or `ledger-maintain-preview-receipt` to stamp the top-level run)  
- Apply: `make ledger-maintain` (or `ledger-maintain-receipt` to stamp the top-level run)

🔒 **Strict / CI:**
- Preview fail-fast: `make ledger-maintain-preview-strict`
- Apply fail-fast: `make ledger-maintain-strict`
- Or set `STRICT=true` on any maintenance target (e.g., `STRICT=true make ledger-maintain-preview`).
- Optional local guard: link `githooks/pre-commit` → `.git/hooks/pre-commit`.

---

## 🛠️ Common Operations

### Start workstation
```bash
gcloud workstations start $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION
```

### Stop workstation
```bash
gcloud workstations stop $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION
```

### Open in browser
```bash
make gcloud-workstation-open
```

### Delete workstation
```bash
make gcloud-workstation-delete        # add FORCE=true to skip prompt
```

### Verify ADC
```bash
gcloud auth application-default print-access-token >/dev/null && echo "✓ ADC working"
```

---

## 📋 Pre-Flight Checklist

Before starting work:
- [ ] ADC authenticated (`gcloud auth application-default login`)
- [ ] `.env` file configured with correct `PROJECT_ID`, `REGION`
- [ ] Service accounts created (`gcloud iam service-accounts list`)
- [ ] Workstation config exists (`gcloud workstations configs list`)
- [ ] Workstation running (`gcloud workstations list`)

---

## 🔥 Troubleshooting

### ADC not working
```bash
gcloud auth application-default login
gcloud auth application-default print-access-token
```

### Missing service accounts
```bash
make gcloud-iam
gcloud iam service-accounts list
```

### Workstation won't start
```bash
# Check status
gcloud workstations describe $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION

# View logs in Cloud Console
```

### Drill fails
```bash
# Check individual tools
command -v pnpm
command -v cargo
gcloud config get-value project
gcloud auth application-default print-access-token
```

---

## 🧰 Bug fixing / bulk fixes

- Single file:
  - `make find-bug FILE=@name`
  - `make find-bug-list FILE=@name`
  - `make find-bug-choose FILE=@name`

- Bulk:
  - `make fix-all` (with INCLUDE/EXCLUDE env)
  - `make fix-all-dry` (no writes, preview only)
  - Ledger: `make fix-all-preview-receipt` (dry-run + receipt), `make fix-all-receipt` (apply + receipt)

💡 **Ritual:** Always run `make fix-all-dry` first to preview changes, then apply with `make fix-all`.

### Examples

- Preview, no writes:
  ```bash
  NON_VENDOR_ONLY=true INCLUDE="**/*.sh **/*.ts" EXCLUDE="**/dist/** **/build/**" make fix-all-dry
  ```

- Run fixes in parallel:
  ```bash
  JOBS=8 INCLUDE="**/*.sh **/*.ts **/*.md" make fix-all
  ```

- Shell only:
  ```bash
  INCLUDE="**/*.sh" make fix-all
  ```

---

## 📦 Environment Setup

```bash
# Copy template
cp .env.example .env

# Required variables
PROJECT_ID=vaultmesh-473618
REGION=europe-west1
WORKSTATION_CONFIG=sovereign-config
WORKSTATION_CLUSTER=sovereign-cluster
WORKSTATION_ID=sovereign-dev
DEPLOYER_SA=vaultmesh-deployer
PROXY_SA=ai-companion-proxy
PUBLISHER_SA=meta-publisher
SCHEDULER_SA=scheduler
```

---

## 🎯 Service Accounts

| SA | Purpose |
|----|---------|
| `vaultmesh-deployer` | Workstation runtime |
| `ai-companion-proxy` | AI companion service |
| `meta-publisher` | Documentation publisher |
| `scheduler` | Cron/scheduled tasks |

---

## 📚 Documentation

- **Full Runbook:** `docs/WORKSTATION_RUNBOOK.md`
- **Repository:** https://github.com/VaultSovereign/sovereign
- **Issues:** https://github.com/VaultSovereign/sovereign/issues

---

**VaultMesh — Earth's Civilization Ledger**  
Sovereign Workstations prove themselves daily ⚔️

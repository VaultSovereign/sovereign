# ⚔️ Sovereign Workstation — Operator Checklist

**Quick reference card for workstation deployment and daily operations.**

---

## 🚀 Bootstrap (One-Time Setup)

```bash
# 1. Auth
gcloud auth login
gcloud auth application-default login

# 2. IAM
make gcloud:iam

# 3. Config
make gcloud:config

# 4. Workstation
make gcloud:workstation

# 5. Drill
make drill
```

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

## 🛠️ Common Operations

### Start workstation
```bash
gcloud workstations workstations start $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION
```

### Stop workstation
```bash
gcloud workstations workstations stop $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION
```

### Open in browser
```bash
gcloud workstations workstations start-tcp-tunnel $WORKSTATION_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION \
  --local-host-port=:8080
```

### Delete workstation
```bash
./gcloud/delete-workstation.sh
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
- [ ] Workstation running (`gcloud workstations workstations list`)

---

## 🔥 Troubleshooting

### ADC not working
```bash
gcloud auth application-default login
gcloud auth application-default print-access-token
```

### Missing service accounts
```bash
make gcloud:iam
gcloud iam service-accounts list
```

### Workstation won't start
```bash
# Check status
gcloud workstations workstations describe $WORKSTATION_ID \
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
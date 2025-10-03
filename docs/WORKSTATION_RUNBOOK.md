# 🛠️ Sovereign Workstation Runbook

Earth's Civilization Ledger — Operator Guide for reproducible, zero-trust development workstations.

---

## ⚡ Overview

The **Sovereign Workstation** is a Google Cloud Workstations environment bound to VaultMesh IAM service accounts, provisioned via Make targets.  
It runs with **ADC (Application Default Credentials)** so no static keys are stored.  
Every day, a **Guardian Drill** emits receipts and a Merkle root to prove the workstation is configured and alive.

---

## 🚀 Bootstrap Flow

### 1. Authenticate with Google Cloud

```bash
gcloud auth login
gcloud auth application-default login
gcloud config list
gcloud auth application-default print-access-token >/dev/null && echo "✓ ADC working"
```

**Expected:** ✅ config shows correct account, project, and region.

---

### 2. Bootstrap IAM Service Accounts

Create the core service accounts for infra and publishing.

```bash
make gcloud:iam
```

This will ensure the following SAs exist:
- **VaultMesh Deployer** — for infra changes (Terraform, Workstations)
- **AI Companion Proxy** — runtime SA for proxy service
- **Meta Publisher** — identity for publishing through proxy
- **Scheduler** — for drills & cron invocations

---

### 3. Create Workstation Config

Build a workstation configuration in your chosen region/cluster.

```bash
make gcloud:config
```

Reads values from `.env` and `workstation/config.yaml`.

---

### 4. Create Workstation Instance

Spawn a new workstation VM from the config:

```bash
make gcloud:workstation
```

This will output a URL — open it in your browser to access the Sovereign dev box.

---

### 5. Run Guardian Drill

Prove the workstation is alive and correct:

```bash
make drill
```

**Outputs:**
- A JSON receipt in `workstation/receipts/drill-<timestamp>.json`
- A daily Merkle root in `workstation/receipts/root-YYYY-MM-DD.json`

---

## 🔑 Daily Ritual

1. Open workstation (`gcloud workstations workstations open ...` or URL).
2. Sync repos (meta, infra-dns, infra-servers).
3. Run drill (`make drill`).
4. Commit receipts (`git add workstation/receipts && git commit -m "drill receipts <date>"`).
5. Push to GitHub — receipts are now canon.

---

## 📂 Repo Map

- `workstation/config.yaml` — source of truth for cluster, SA, machine type
- `workstation/startup.sh` — one-time bootstrap (node, rust, pnpm, etc.)
- `workstation/poststart.sh` — runs every boot (dotfiles, env)
- `workstation/drills/guardian-drill.sh` — health & receipt generator
- `workstation/receipts/` — daily JSON receipts + Merkle roots

---

## 🛡️ Security Principles

- **ADC First** — no service account key files
- **Least Privilege** — each runtime has its own SA with minimal roles
- **Receipts Always** — every day yields a signed JSON receipt + Merkle root
- **Immutable Ledger** — receipts are committed, not edited

---

## 🧩 Next Steps

- Add `CHANNEL_DISCOURSE=1` to meta → auto-publish to Polis.
- Wire `make drill` into Cloud Scheduler → daily automatic receipts.
- Extend `drills/` with performance checks (disk, CPU, tailscale status).

---

**VaultMesh — Earth's Civilization Ledger**  
Sovereign Workstations prove themselves daily ⚔️

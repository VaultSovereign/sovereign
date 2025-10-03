# 🛡️ Sovereign Workstation — Security Model

The Sovereign Workstation is designed for **zero-trust operation**:
- **ADC-first**: no static JSON key files; all access via `gcloud auth application-default login`.
- **Least privilege**: each service account (SA) has only the roles required for its function.
- **Receipts as proof**: every drill produces immutable receipts and Merkle roots.

---

## Operator Security Practices

- **Never commit `.env`** — it is ignored by `.gitignore`.  
- **Rotate ephemeral keys** — Tailscale, Slack, etc. every 30 days.  
- **Daily proof** — always run `make drill` and commit the receipts.  
- **Audit SAs** — review IAM bindings monthly:
  ```bash
  gcloud projects get-iam-policy $PROJECT_ID
  ```
- **Shield secrets** — use GCP Secret Manager or GitHub Secrets, never plaintext `.env` in history.

---

## Threat Model

- **Compromised laptop**: mitigated by ephemeral workstation + ADC refresh.
- **Leaked service account key**: mitigated by never generating JSON keys.
- **Drift**: mitigated by Guardian Drill receipts + Merkle root anchoring.
- **Data tamper**: content-addressed IDs (BLAKE3/SHA256) ensure immutability.

---

## Red Flags

- **Drill fails on `adc` check** → re-run `gcloud auth application-default login`.
- **Unknown IAM members in `roles/run.invoker`** → remove immediately.
- **Missing receipts for a day** → treat as DEGRADED, escalate.

---

**Steel sung. Ledger sealed. Polis eternal.**
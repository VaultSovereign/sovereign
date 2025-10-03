# 📜 Sovereign Workstation — Receipts

Every workstation drill produces verifiable JSON receipts and daily Merkle roots.  
Receipts are **immutable proofs** of environment health and security posture.

---

## Receipt Structure

Example: `workstation/receipts/drill-20251003T072045Z.json`

```json
{
  "kind": "vaultmesh.workstation.guardian_drill.v1",
  "ts": "20251003T072045Z",
  "project": "vaultmesh-473618",
  "region": "europe-west1",
  "checks": [
    {"check": "gcloud-project", "ok": true},
    {"check": "adc", "ok": true},
    {"check": "pnpm", "ok": true},
    {"check": "rust", "ok": true},
    {"check": "cf-token", "ok": true}
  ]
}
```

- **`kind`** — schema identifier
- **`ts`** — UTC timestamp
- **`project`, `region`** — bound GCP context
- **`checks`** — array of validations (binary outcome)

---

## Merkle Root

Example: `workstation/receipts/root-2025-10-03.json`

```json
{
  "day": "2025-10-03",
  "root": "cb8abdca06a3274420d87a7eba32d278bacfd8ed4830a6aa1a4975a8dd754d65"
}
```

- **`day`** — date in UTC
- **`root`** — BLAKE3 digest of all receipts for that day

---

## Verification Ritual

1. **Run daily drill:**
   ```bash
   make drill
   ```

2. **Validate schema:**
   ```bash
   jq .kind workstation/receipts/drill-*.json
   ```

3. **Recompute root:**
   ```bash
   find workstation/receipts -name 'drill-20251003*.json' -print0 \
     | xargs -0 b3sum | awk '{print $1}' | b3sum
   ```
   Compare output to `root-2025-10-03.json`.

---

## Storage & Retention

- **Keep 30 days** of receipts in repo.
- **Archive older receipts** to cold storage (GCS bucket, immutability lock).
- **Never delete Merkle roots**; they are covenant seals.

---

**Right to Proofs → Every day, every drill, every root.**
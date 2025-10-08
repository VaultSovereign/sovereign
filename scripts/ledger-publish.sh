#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAILY_DIR="$ROOT_DIR/workstation/receipts/daily"
PROOFS_DIR="$DAILY_DIR/proofs"

BUCKET="${PUBLISH_BUCKET:-}"
DRY="${DRY_RUN:-false}"
KMS_KEY="${KMS_KEY_URI:-}"    # optional: projects/.../locations/.../keyRings/.../cryptoKeys/...

err() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[publish-ledger] $*"; }

[[ -d "$DAILY_DIR" ]] || err "Missing $DAILY_DIR; run 'make ledger-maintain' first."
[[ -n "$BUCKET" ]] || err "Set PUBLISH_BUCKET (e.g., gs://sovereign-roots)."

if ! command -v gsutil >/dev/null 2>&1; then
  err "gsutil not found in PATH. Install Google Cloud SDK."
fi

log "Target bucket: $BUCKET (dry_run=$DRY)"
log "Syncing daily roots and proofs…"

copy() {
  local src="$1" dst="$2"
  if [[ "$DRY" == "true" ]]; then
    log "DRY RUN: gsutil -m rsync -r -d \"$src\" \"$dst\""
  else
    gsutil -m rsync -r -d "$src" "$dst"
  fi
}

copy "$DAILY_DIR" "$BUCKET/daily"
copy "$PROOFS_DIR" "$BUCKET/daily/proofs"

if [[ -n "$KMS_KEY" && "$DRY" != "true" ]]; then
  log "KMS signing hook is present; you can implement object signing here if desired."
fi

log "Done. Consider bucket retention policy & public read mirror if appropriate."

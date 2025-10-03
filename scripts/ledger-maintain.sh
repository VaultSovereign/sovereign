#!/usr/bin/env bash
set -euo pipefail
# Ledger Maintenance Ritual: plan → act → prove (and stamp)
#
# Modes:
#   DRY_RUN=true  → plan-only: compact-dryrun, fix-all-preview-receipt, verify (no writes)
#   DRY_RUN=false → apply:     compact, verify, fix-all-receipt
#
# Inputs (env passthroughs to existing targets):
#   KEEP (default 5), VERBOSE (default false)
#   INCLUDE, EXCLUDE, NON_VENDOR_ONLY (default true), JOBS, SEARCH_ROOT
#
# Receipts:
#   RECEIPT=true → writes workstation/receipts/maintenance-<ts>.json summarizing sub-steps

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
VALIDATOR="$ROOT_DIR/scripts/receipt-validate.sh"

DRY="${DRY_RUN:-false}"
RECEIPT="${RECEIPT:-false}"
RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
RECEIPT_PREFIX="${RECEIPT_PREFIX:-maintenance}"
STRICT="${STRICT:-false}"

mkdir -p "$RECEIPTS_DIR"

run() { echo "→ $*"; eval "$*"; }

verify_rc=0

if [[ "$DRY" == "true" ]]; then
  echo "🜁 Maintenance (preview mode)"
  run 'KEEP=${KEEP:-5} VERBOSE=${VERBOSE:-true} make ledger-compact-dryrun'
  if STRICT="$STRICT" make ledger-verify; then
    verify_rc=0
  else
    verify_rc=$?
  fi
  run 'NON_VENDOR_ONLY=${NON_VENDOR_ONLY:-true} INCLUDE="${INCLUDE:-}" EXCLUDE="${EXCLUDE:-}" JOBS="${JOBS:-}" SEARCH_ROOT="${SEARCH_ROOT:-.}" make fix-all-preview-receipt'
  MODE="dry-run"
else
  echo "🜂 Maintenance (apply mode)"
  run 'NON_VENDOR_ONLY=${NON_VENDOR_ONLY:-true} INCLUDE="${INCLUDE:-}" EXCLUDE="${EXCLUDE:-}" JOBS="${JOBS:-}" SEARCH_ROOT="${SEARCH_ROOT:-.}" make fix-all-receipt'
  run 'KEEP=${KEEP:-5} make ledger-compact'
  if STRICT="$STRICT" make ledger-verify; then
    verify_rc=0
  else
    verify_rc=$?
  fi
  MODE="apply"
fi

# Optional top-level maintenance receipt
if [[ "$RECEIPT" == "true" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  out="${RECEIPTS_DIR}/${RECEIPT_PREFIX}-${ts}.json"
  if command -v jq >/dev/null 2>&1; then
    last_fix="$(ls -1t "${RECEIPTS_DIR}"/fixall-*.json 2>/dev/null | head -n1 || true)"
    jq -n \
      --arg kind "maintenance.run" \
      --arg ts "$ts" \
      --arg mode "$MODE" \
      --arg keep "${KEEP:-5}" \
      --arg include "${INCLUDE:-}" \
      --arg exclude "${EXCLUDE:-}" \
      --arg non_vendor_only "${NON_VENDOR_ONLY:-true}" \
      --arg jobs "${JOBS:-}" \
      --arg strict "$STRICT" \
      --argjson verify_ok "$([[ ${verify_rc:-0} -eq 0 ]] && echo true || echo false)" \
      --arg fixall_receipt "${last_fix##*/}" \
      '{
        kind:$kind, ts:$ts, mode:$mode,
        params:{
          keep: ($keep|tonumber?),
          include: ([$include]|map(select(length>0))|.[0]//""|split(" ")|map(select(length>0))),
          exclude: ([$exclude]|map(select(length>0))|.[0]//""|split(" ")|map(select(length>0))),
          non_vendor_only: ($non_vendor_only=="true"),
          jobs: ($jobs|tonumber?),
          strict: ($strict=="true")
        },
        links:{
          fixall_receipt: ( $fixall_receipt | select(length>0) )
        },
        verify_ok: $verify_ok,
        status: (if $verify_ok then "ok" else "verify_mismatch" end)
      }' > "$out.tmp"
    if "$VALIDATOR" "$out.tmp"; then
      mv "$out.tmp" "$out"
      echo "🧾 Maintenance receipt: $out"
    else
      echo "✖ invalid receipt, not written"
      rm -f "$out.tmp"
      exit 2
    fi
  else
    echo "⚠ jq not found; skipping maintenance receipt." >&2
  fi
fi
if [[ "$STRICT" == "true" && ${verify_rc:-0} -ne 0 ]]; then
  echo "✖ Maintenance ${MODE} failed: ledger-verify mismatch (STRICT=true)."
  exit ${verify_rc:-1}
fi

echo "✔ Maintenance ${MODE} complete."

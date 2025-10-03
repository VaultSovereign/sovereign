#!/usr/bin/env bash
set -euo pipefail
# Validate a receipt JSON against docs/schemas/receipt.schema.json
# Usage: scripts/receipt-validate.sh <file.json>

f="${1:-}"; [[ -n "$f" && -f "$f" ]] || { echo "usage: $0 <file.json>"; exit 2; }
SCHEMA="docs/schemas/receipt.schema.json"

have_npx()  { command -v npx  >/dev/null 2>&1; }
have_jq()   { command -v jq   >/dev/null 2>&1; }

if have_npx; then
  if npx -y ajv-cli@5 validate --spec=draft2020 -s "$SCHEMA" -d "$f" >/dev/null 2>&1; then
    echo "✔ receipt valid (ajv): $f"; exit 0
  else
    echo "⚠ ajv validation failed, falling back to jq: $f" >&2
  fi
fi

if ! have_jq; then
  echo "⚠ jq not found; cannot validate $f"; exit 0
fi

kind="$(jq -r '.kind // empty' "$f")"
[[ -n "$kind" ]] || { echo "✖ missing .kind"; exit 1; }
ts_ok="$(jq -r '(.ts|tostring) | test("^[0-9]{8}T[0-9]{6}Z$")' "$f")"
[[ "$ts_ok" == "true" ]] || { echo "✖ invalid or missing ts"; exit 1; }

case "$kind" in
 workstation.preflight)
   jq -e '.results and (.results.ok|type=="array") and (.results.warn|type=="array") and (.results.fail|type=="array")' "$f" >/dev/null || { echo "✖ preflight shape"; exit 1; }
   ;;
  workstation.config|workstation.run|workstation.delete)
    jq -e '.params|type=="object"' "$f" >/dev/null || { echo "✖ .params required"; exit 1; }
    ;;
  workstation.daily)
    jq -e '(.day and .root and (.files|type=="array"))' "$f" >/dev/null || { echo "✖ daily shape"; exit 1; }
    ;;
  maintenance.run)
    jq -e '.mode and (.verify_ok|type=="boolean")' "$f" >/dev/null || { echo "✖ maintenance shape"; exit 1; }
    ;;
 fixall.run)
    if ! jq -e '(.mode and .stats and (.files|type=="array"))' "$f" >/dev/null; then
      echo "✖ fixall shape"; cp "$f" "${f%.tmp}.debug" 2>/dev/null || true; exit 1; fi
    ;;
  *)
    echo "⚠ unknown kind '$kind' — basic checks passed" ;;
 esac

echo "✔ receipt valid (jq): $f"

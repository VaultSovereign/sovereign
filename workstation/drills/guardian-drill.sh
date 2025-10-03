#!/usr/bin/env bash
set -euo pipefail
TS=$(date -u +"%Y%m%dT%H%M%SZ")
OUT="workstation/receipts/drill-$TS.json"
ROOTOUT="workstation/receipts/root-$(date -u +%F).json"

ok=true
check(){ name=$1; shift; if "$@"; then echo "{\"check\":\"$name\",\"ok\":true}"; else ok=false; echo "{\"check\":\"$name\",\"ok\":false}"; fi }

mkdir -p workstation/receipts

# --- extra checks: tailscale + dns + cf edge ---
has() { command -v "$1" >/dev/null 2>&1; }

# tailscale daemon healthy
if has tailscale; then
  ts_status=$(check "tailscale-status" sh -c 'tailscale status --json | jq -e .BackendState | grep -q Running')
  ts_ipv4=$(check "tailscale-ipv4-100net" sh -c 'tailscale ip -4 | grep -qE "^100\\."')
else
  echo '{"check":"tailscale-status","ok":false}'
  echo '{"check":"tailscale-ipv4-100net","ok":false}'
  ok=false
  ts_status='{"check":"tailscale-status","ok":false}'
  ts_ipv4='{"check":"tailscale-ipv4-100net","ok":false}'
fi

# dns: vaultmesh.org resolves (A or AAAA)
dns_check=$(check "dns-vaultmesh-org" sh -c 'getent ahosts vaultmesh.org >/dev/null 2>&1')

# http: served via Cloudflare (server header)
cf_check=$(check "http-cloudflare-edge" sh -c "curl -fsSI https://vaultmesh.org | tr -d '\\r' | grep -iq '^server:.*cloudflare'")

R=$(cat <<JSON
{
  "kind":"vaultmesh.workstation.guardian_drill.v1",
  "ts":"$TS",
  "project":"${PROJECT_ID:-unknown}",
  "region":"${REGION:-unknown}",
  "checks":[
    $(check "gcloud-project" sh -c 'gcloud config get-value project >/dev/null 2>&1'),
    $(check "adc"          sh -c 'gcloud auth application-default print-access-token >/dev/null 2>&1'),
    $(check "pnpm"         sh -c 'command -v pnpm >/dev/null'),
    $(check "rust"         sh -c 'command -v cargo >/dev/null'),
    $(check "cf-token"     sh -c 'test -n "${CF_API_TOKEN:-}"'),
    $ts_status,
    $ts_ipv4,
    $dns_check,
    $cf_check
  ]
}
JSON
)

echo "$R" | jq . > "$OUT"

# naive merkle: b3sum of receipts of the day
if command -v b3sum >/dev/null; then
  root=$(find workstation/receipts -maxdepth 1 -type f -name "drill-$(date -u +%Y%m%d)*.json" -print0 \
    | xargs -0 b3sum | awk '{print $1}' | b3sum | awk '{print $1}')
  printf '{"day":"%s","root":"%s"}\n' "$(date -u +%F)" "$root" | tee "$ROOTOUT"
fi

[ "$ok" = true ] && echo "DRILL OK" || (echo "DRILL DEGRADED"; exit 1)
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
VALIDATOR="$ROOT_DIR/scripts/receipt-validate.sh"

# Guardian: Workstations command resolver (GA -> beta -> alpha)
gcloud_ws() {
  if gcloud workstations --help >/dev/null 2>&1; then
    gcloud workstations "$@"
  elif gcloud beta workstations --help >/dev/null 2>&1; then
    gcloud beta workstations "$@"
  else
    gcloud alpha workstations "$@"
  fi
}

# Inputs (env overrides allowed)
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${REGION:-europe-west3}"
NETWORK="${NETWORK:-}"
SUBNETWORK="${SUBNETWORK:-}"
AUTO_ENABLE="${AUTO_ENABLE:-false}"
RECEIPT="${RECEIPT:-false}"
RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
RECEIPT_PREFIX="${RECEIPT_PREFIX:-preflight}"

ok=()
warn=()
fail=()

say() { printf "%b %s\n" "$1" "$2"; }
add_ok() { ok+=("$1"); say "✔" "$1"; }
add_warn() { warn+=("$1"); say "⚠" "$1"; }
add_fail() { fail+=("$1"); say "✖" "$1"; }
section() { printf "\n━━ %s ━━\n" "$1"; }

section "Preflight — Identity & Tooling"
if command -v gcloud >/dev/null 2>&1; then
  add_ok "gcloud present ($(gcloud --version | head -n1))"
else
  add_fail "gcloud CLI not found in PATH"
fi

if gcloud auth application-default print-access-token >/dev/null 2>&1; then
  add_ok "ADC available (application-default credentials)"
else
  add_fail "ADC missing. Run: gcloud auth application-default login"
fi

if [[ -n "${PROJECT_ID}" ]]; then
  add_ok "Project resolved: ${PROJECT_ID}"
else
  add_fail "No gcloud project set. Run: gcloud config set project <PROJECT_ID>"
fi

section "Preflight — APIs"
need_api=( "workstations.googleapis.com" )
for svc in "${need_api[@]}"; do
  if gcloud services list --enabled --format="value(config.name)" | grep -qx "${svc}"; then
    add_ok "API enabled: ${svc}"
  else
    if [[ "${AUTO_ENABLE}" == "true" && -n "${PROJECT_ID}" ]]; then
      say "…" " Enabling ${svc} (AUTO_ENABLE=true)"
      if gcloud services enable "${svc}"; then
        add_ok "API enabled now: ${svc}"
      else
        add_fail "Failed to enable API: ${svc}"
      fi
    else
      add_fail "API disabled: ${svc} (set AUTO_ENABLE=true to auto-enable)"
    fi
  fi
done

section "Preflight — Region & Endpoint"
if gcloud_ws clusters list --location="${REGION}" --format="value(name)" >/dev/null 2>&1; then
  add_ok "Workstations endpoint reachable in ${REGION}"
else
  add_warn "Workstations endpoint probe failed in ${REGION} (permissions or region support)"
fi

section "Preflight — Quotas (informational)"
if gcloud compute regions describe "${REGION}" --format="value(quotas.quota,quotas.metric,quotas.usage)" >/dev/null 2>&1; then
  cpu_line="$(gcloud compute regions describe "${REGION}" --format="csv[no-heading](quotas.metric,quotas.usage,quotas.quota)" | grep -E '^CPUS,' || true)"
  if [[ -n "${cpu_line}" ]]; then
    IFS=',' read -r metric used total <<<"${cpu_line}"
    add_ok "Compute quota ${metric}: ${used}/${total} used (region ${REGION})"
  else
    add_warn "Compute CPU quota not visible; continuing"
  fi
else
  add_warn "Could not read Compute region quotas; continuing"
fi

section "Preflight — Network (optional)"
normalize_network() {
  local net="$1"
  if [[ "$net" == projects/*/global/networks/* ]]; then
    printf '%s\n' "$net"
  elif [[ -n "${PROJECT_ID}" && -n "$net" ]]; then
    printf 'projects/%s/global/networks/%s\n' "${PROJECT_ID}" "$net"
  fi
}
normalize_subnet() {
  local sn="$1"
  if [[ "$sn" == projects/*/regions/*/subnetworks/* ]]; then
    printf '%s\n' "$sn"
  elif [[ -n "${PROJECT_ID}" && -n "$sn" ]]; then
    printf 'projects/%s/regions/%s/subnetworks/%s\n' "${PROJECT_ID}" "${REGION}" "$sn"
  fi
}

NET_FULL="$(normalize_network "${NETWORK}")"
SUBNET_FULL="$(normalize_subnet "${SUBNETWORK}")"

if [[ -n "${NETWORK}" ]]; then
  if gcloud compute networks describe "${NET_FULL}" >/dev/null 2>&1; then
    add_ok "Network present: ${NET_FULL}"
  else
    add_fail "Network not found: ${NET_FULL:-${NETWORK}}"
  fi
else
  add_warn "NETWORK not provided (skipping network existence check)"
fi

if [[ -n "${SUBNETWORK}" ]]; then
  if gcloud compute networks subnets describe "${SUBNET_FULL}" >/dev/null 2>&1; then
    add_ok "Subnetwork present: ${SUBNET_FULL}"
  else
    add_fail "Subnetwork not found: ${SUBNET_FULL:-${SUBNETWORK}}"
  fi
else
  add_warn "SUBNETWORK not provided (skipping subnetwork check)"
fi

section "Preflight — IAM (informational)"
if gcloud_ws clusters list --location="${REGION}" --format="value(name)" >/dev/null 2>&1; then
  add_ok "Caller can list clusters (Workstations permissions likely OK)"
else
  add_warn "Could not list clusters; ensure roles like roles/workstations.user and SA bindings"
fi

section "Summary"
printf "OK: %d  WARN: %d  FAIL: %d\n" "${#ok[@]}" "${#warn[@]}" "${#fail[@]}"

# Receipt emission (optional)
status="ok"
exit_code=0
if (( ${#fail[@]} > 0 )); then
  status="fail"; exit_code=2
elif (( ${#warn[@]} > 0 )); then
  status="warn"; exit_code=0
fi

if [[ "${RECEIPT}" == "true" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "${RECEIPTS_DIR}"
  out="${RECEIPTS_DIR}/${RECEIPT_PREFIX}-${ts}.json"
  if command -v jq >/dev/null 2>&1; then
    ok_json='[]'; warn_json='[]'; fail_json='[]'
    if (( ${#ok[@]} )); then ok_json="$(printf '%s\n' "${ok[@]}" | jq -R . | jq -s .)"; fi
    if (( ${#warn[@]} )); then warn_json="$(printf '%s\n' "${warn[@]}" | jq -R . | jq -s .)"; fi
    if (( ${#fail[@]} )); then fail_json="$(printf '%s\n' "${fail[@]}" | jq -R . | jq -s .)"; fi
    jq -n \
      --arg kind "workstation.preflight" \
      --arg ts "$ts" \
      --arg project "${PROJECT_ID:-}" \
      --arg region "$REGION" \
      --arg network_input "$NETWORK" \
      --arg network_full "${NET_FULL:-}" \
      --arg subnetwork_input "$SUBNETWORK" \
      --arg subnetwork_full "${SUBNET_FULL:-}" \
      --arg status "$status" \
      --argjson exit_code "$exit_code" \
      --argjson ok "$ok_json" \
      --argjson warn "$warn_json" \
      --argjson fail "$fail_json" \
      '{
        kind: $kind, ts: $ts,
        project: $project, region: $region,
        network: { input: $network_input, full: $network_full },
        subnetwork: { input: $subnetwork_input, full: $subnetwork_full },
        results: { ok: $ok, warn: $warn, fail: $fail },
        status: $status, exit_code: $exit_code
      }' > "$out.tmp"
    if "$VALIDATOR" "$out.tmp"; then
      mv "$out.tmp" "$out"
      echo "\xF0\x9F\xA7\xBE Preflight receipt: $out"
    else
      echo "✖ invalid receipt, not written"
      rm -f "$out.tmp"
      exit 2
    fi
  else
    echo "\xE2\x9A\xA0 jq not found; skipping JSON receipt. Install jq or run RECEIPT=false." >&2
  fi
fi

exit "$exit_code"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
VALIDATOR="$ROOT_DIR/scripts/receipt-validate.sh"

# Receipt controls (opt-in)
RECEIPT="${RECEIPT:-false}"
RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
RECEIPT_PREFIX="${RECEIPT_PREFIX:-workstation}"

GCLOUD_WS_TRACK=""

# Guardian: Workstations command resolver (GA -> beta -> alpha)
gcloud_ws() {
  if gcloud workstations --help >/dev/null 2>&1; then
    GCLOUD_WS_TRACK="ga"
    gcloud workstations "$@"
  elif gcloud beta workstations --help >/dev/null 2>&1; then
    GCLOUD_WS_TRACK="beta"
    gcloud beta workstations "$@"
  else
    GCLOUD_WS_TRACK="alpha"
    gcloud alpha workstations "$@"
  fi
}

# Inputs
. ./.env 2>/dev/null || true
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-europe-west3}"
CLUSTER_ID="${CLUSTER_ID:-${WORKSTATION_CLUSTER:-g-forge}}"
CONFIG_ID="${CONFIG_ID:-${WORKSTATION_CONFIG:-config-mgalrsbs}}"
WORKSTATION_ID="${WORKSTATION_ID:-sovereign-dev}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "ERROR: PROJECT_ID not set and gcloud default project is empty." >&2
  exit 1
fi

echo "Using project=${PROJECT_ID} region=${REGION} cluster=${CLUSTER_ID} config=${CONFIG_ID} workstation=${WORKSTATION_ID}"

# Ensure cluster/config exist
gcloud_ws clusters describe "${CLUSTER_ID}" --region="${REGION}" >/dev/null 2>&1 || {
  echo "ERROR: Cluster ${CLUSTER_ID} not found in ${REGION}. Run gcloud/create-config.sh first." >&2
  exit 2
}
gcloud_ws configs describe "${CONFIG_ID}" --cluster="${CLUSTER_ID}" --region="${REGION}" >/dev/null 2>&1 || {
  echo "ERROR: Config ${CONFIG_ID} not found on cluster ${CLUSTER_ID}. Run gcloud/create-config.sh first." >&2
  exit 3
}

# Create workstation (idempotent)
steps=()
existed_ws=false
resolved_url=""

if gcloud_ws describe "${WORKSTATION_ID}" --cluster="${CLUSTER_ID}" --config="${CONFIG_ID}" --region="${REGION}" >/dev/null 2>&1; then
  existed_ws=true
  echo "Workstation ${WORKSTATION_ID} already exists."
else
  echo "Creating workstation ${WORKSTATION_ID}…"
  gcloud_ws create "${WORKSTATION_ID}" \
    --cluster="${CLUSTER_ID}" \
    --config="${CONFIG_ID}" \
    --region="${REGION}"; steps+=("workstations.create")
fi

# Start workstation (idempotent)
echo "Starting workstation ${WORKSTATION_ID}…"
gcloud_ws start "${WORKSTATION_ID}" \
  --cluster="${CLUSTER_ID}" \
  --config="${CONFIG_ID}" \
  --region="${REGION}"; steps+=("workstations.start")

# Resolve URL
echo "Resolving access URL…"
if gcloud_ws open --help >/dev/null 2>&1; then
  gcloud_ws open "${WORKSTATION_ID}" \
    --cluster="${CLUSTER_ID}" \
    --config="${CONFIG_ID}" \
    --region="${REGION}" \
    --dry-run 2>/dev/null || true
fi

HOST=$(gcloud_ws describe "${WORKSTATION_ID}" --cluster="${CLUSTER_ID}" --config="${CONFIG_ID}" --region="${REGION}" --format='value(host)' 2>/dev/null || true)
if [[ -n "${HOST}" ]]; then
  echo "Open: https://${HOST}"; resolved_url="https://${HOST}"
else
  echo "Open via Cloud Console → Workstations → ${REGION} → ${CLUSTER_ID} → ${WORKSTATION_ID}"
fi

# Optional receipt emission
if [[ "${RECEIPT}" == "true" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "${RECEIPTS_DIR}"
  out="${RECEIPTS_DIR}/${RECEIPT_PREFIX}-${ts}.json"
  if command -v jq >/dev/null 2>&1; then
    tmpsteps="${RECEIPTS_DIR}/.steps.$$"; printf '%s\n' "${steps[@]}" | jq -R . | jq -s . >"$tmpsteps"
    jq -n \
      --arg kind "workstation.run" \
      --arg ts "$ts" \
      --arg track "$GCLOUD_WS_TRACK" \
      --arg project "${PROJECT_ID:-}" \
      --arg region "$REGION" \
      --arg cluster "$CLUSTER_ID" \
      --arg config "$CONFIG_ID" \
      --arg workstation "$WORKSTATION_ID" \
      --arg url "$resolved_url" \
      --argjson existed "$existed_ws" \
      --slurpfile steps "$tmpsteps" \
      '{kind:$kind, ts:$ts, track:$track, project:$project, region:$region,
        cluster:$cluster, config:$config, workstation:$workstation,
        existed:{workstation:$existed}, steps:$steps[0], url:($url|select(.!="")),
        status:"ok"}' > "$out.tmp"
    rm -f "$tmpsteps"
    if "$VALIDATOR" "$out.tmp"; then
      mv "$out.tmp" "$out"
      echo "🧾 Workstation receipt: $out"
    else
      echo "✖ invalid receipt, not written"
      rm -f "$out.tmp"
      exit 2
    fi
  else
    echo "⚠ jq not found; skipping workstation receipt." >&2
  fi
fi

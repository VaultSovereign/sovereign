#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
VALIDATOR="$ROOT_DIR/scripts/receipt-validate.sh"

# Receipt controls (opt-in)
RECEIPT="${RECEIPT:-false}"
RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
RECEIPT_PREFIX="${RECEIPT_PREFIX:-delete}"

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
FORCE="${FORCE:-false}"
STOP_FIRST="${STOP_FIRST:-true}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "ERROR: PROJECT_ID not set and gcloud default project is empty." >&2
  exit 1
fi

echo "Target: project=${PROJECT_ID} region=${REGION} cluster=${CLUSTER_ID} config=${CONFIG_ID} workstation=${WORKSTATION_ID}"
existed_cluster=false
existed_config=false
existed_ws=false
steps=()

# Existence checks (do not exit immediately to allow a receipt)
if gcloud_ws clusters describe "${CLUSTER_ID}" --region="${REGION}" >/dev/null 2>&1; then
  existed_cluster=true
else
  echo "Nothing to do: cluster ${CLUSTER_ID} not found in ${REGION}."
fi
if gcloud_ws configs describe "${CONFIG_ID}" --cluster="${CLUSTER_ID}" --region="${REGION}" >/dev/null 2>&1; then
  existed_config=true
else
  echo "Nothing to do: config ${CONFIG_ID} not found on cluster ${CLUSTER_ID}."
fi
if gcloud_ws describe "${WORKSTATION_ID}" --cluster="${CLUSTER_ID}" --config="${CONFIG_ID}" --region="${REGION}" >/dev/null 2>&1; then
  existed_ws=true
else
  echo "Nothing to delete: workstation ${WORKSTATION_ID} does not exist."
fi

# Stop first (best practice), ignore errors if already stopped
if [[ "${STOP_FIRST}" == "true" && "${existed_ws}" == "true" ]]; then
  echo "Stopping ${WORKSTATION_ID} (if running)…"
  gcloud_ws stop "${WORKSTATION_ID}" \
    --cluster="${CLUSTER_ID}" \
    --config="${CONFIG_ID}" \
    --region="${REGION}" \
    >/dev/null 2>&1 || true
  steps+=("workstations.stop")
fi

if [[ "${existed_ws}" == "true" ]]; then
  echo "Deleting workstation ${WORKSTATION_ID}…"
  del_args=( delete "${WORKSTATION_ID}" --cluster="${CLUSTER_ID}" --config="${CONFIG_ID}" --region="${REGION}" )
  if [[ "${FORCE}" == "true" ]]; then del_args+=( --quiet ); fi
  gcloud_ws "${del_args[@]}"; steps+=("workstations.delete")
  echo "Deleted ${WORKSTATION_ID}."
fi

# Optional receipt emission
if [[ "${RECEIPT}" == "true" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "${RECEIPTS_DIR}"
  out="${RECEIPTS_DIR}/${RECEIPT_PREFIX}-${ts}.json"
  if command -v jq >/dev/null 2>&1; then
    tmpsteps="${RECEIPTS_DIR}/.steps.$$"; printf '%s\n' "${steps[@]}" | jq -R . | jq -s . >"$tmpsteps"
    jq -n \
      --arg kind "workstation.delete" \
      --arg ts "$ts" \
      --arg track "$GCLOUD_WS_TRACK" \
      --arg project "${PROJECT_ID:-}" \
      --arg region "$REGION" \
      --arg cluster "$CLUSTER_ID" \
      --arg config "$CONFIG_ID" \
      --arg workstation "$WORKSTATION_ID" \
      --arg stop_first "$STOP_FIRST" \
      --arg force "$FORCE" \
      --argjson existed_cluster "$existed_cluster" \
      --argjson existed_config "$existed_config" \
      --argjson existed_ws "$existed_ws" \
      --slurpfile steps "$tmpsteps" \
      '{kind:$kind, ts:$ts, track:$track, project:$project, region:$region,
        cluster:$cluster, config:$config, workstation:$workstation,
        existed:{cluster:$existed_cluster, config:$existed_config, workstation:$existed_ws},
        params:{stop_first:($stop_first=="true"), force:($force=="true")}, steps:$steps[0], status:"ok"}' > "$out.tmp"
    rm -f "$tmpsteps"
    if "$VALIDATOR" "$out.tmp"; then
      mv "$out.tmp" "$out"
      echo "🧾 Delete receipt: $out"
    else
      echo "✖ invalid receipt, not written"
      rm -f "$out.tmp"
      exit 2
    fi
  else
    echo "⚠ jq not found; skipping delete receipt." >&2
  fi
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
VALIDATOR="$ROOT_DIR/scripts/receipt-validate.sh"

# Receipt controls (opt-in)
RECEIPT="${RECEIPT:-false}"
RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
RECEIPT_PREFIX="${RECEIPT_PREFIX:-config}"

# Track marker (GA|beta|alpha)
GCLOUD_WS_TRACK=""

# Guardian: Resolve Workstations command group (GA -> beta -> alpha)
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

# Load env (optional) and inputs
. ./.env 2>/dev/null || true
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-europe-west3}"
# Support both legacy and new var names
CLUSTER_ID="${CLUSTER_ID:-${WORKSTATION_CLUSTER:-g-forge}}"
CONFIG_ID="${CONFIG_ID:-${WORKSTATION_CONFIG:-sovereign-config}}"

# Export variables required by envsubst for workstation/config.yaml
export PROJECT_ID REGION
export WORKSTATION_CLUSTER="$CLUSTER_ID"
export WORKSTATION_CONFIG="$CONFIG_ID"
WORKSTATION_ID="${WORKSTATION_ID:-sovereign-dev}"; export WORKSTATION_ID
DEPLOYER_SA="${DEPLOYER_SA:-vaultmesh-deployer}"; export DEPLOYER_SA

# Normalize network/subnetwork to full resource paths
NETWORK="${NETWORK:-default}"
SUBNETWORK="${SUBNETWORK:-}"
normalize_network() {
  local net="$1"
  if [[ "$net" == projects/*/global/networks/* ]]; then echo "$net"; else echo "projects/${PROJECT_ID}/global/networks/${net}"; fi
}
normalize_subnetwork() {
  local sn="$1"
  if [[ -z "$sn" ]]; then return 0; fi
  if [[ "$sn" == projects/*/regions/*/subnetworks/* ]]; then echo "$sn"; else echo "projects/${PROJECT_ID}/regions/${REGION}/subnetworks/${sn}"; fi
}
NETWORK_FULL="$(normalize_network "$NETWORK")"
SUBNETWORK_FULL="$(normalize_subnetwork "$SUBNETWORK" || true)"

# Map YAML disk_type to valid PD type flag
map_pd_type() {
  case "${1^^}" in
    BALANCED) echo pd-balanced ;;
    PERFORMANCE|SSD) echo pd-ssd ;;
    STANDARD|HDD) echo pd-standard ;;
    pd-balanced|pd-ssd|pd-standard) echo "$1" ;;
    *) echo pd-standard ;;
  esac
}

# Project and API enablement
if [[ -n "$PROJECT_ID" ]]; then
  gcloud config set project "$PROJECT_ID" >/dev/null
fi
gcloud services enable workstations.googleapis.com >/dev/null

# Parse workstation/config.yaml for SA and machine sizing
SA=$(envsubst < workstation/config.yaml | yq eval -r '.service_account' -)
CPU=$(envsubst < workstation/config.yaml | yq eval -r '.machine.cpu' -)
DISK_GB=$(envsubst < workstation/config.yaml | yq eval -r '.machine.disk_gb' -)
RAW_TYPE=$(envsubst < workstation/config.yaml | yq eval -r '.machine.disk_type' -)
PD_TYPE=$(map_pd_type "$RAW_TYPE")
MACHINE_TYPE="e2-standard-${CPU}"

# Create cluster (idempotent)
steps=()
existed_cluster=false
existed_config=false

if gcloud_ws clusters describe "$CLUSTER_ID" --region="$REGION" >/dev/null 2>&1; then
  existed_cluster=true
else
  args=(clusters create "$CLUSTER_ID" --region="$REGION" --network="$NETWORK_FULL")
  if [[ -n "${SUBNETWORK_FULL:-}" ]]; then args+=( --subnetwork="$SUBNETWORK_FULL" ); fi
  gcloud_ws "${args[@]}"; steps+=("clusters.create")
fi

# Create config (idempotent)
if gcloud_ws configs describe "$CONFIG_ID" --cluster="$CLUSTER_ID" --region="$REGION" >/dev/null 2>&1; then
  existed_config=true
else
  gcloud_ws configs create "$CONFIG_ID" \
    --cluster="$CLUSTER_ID" --region="$REGION" \
    --machine-type="$MACHINE_TYPE" \
    --pd-disk-type="$PD_TYPE" --pd-disk-size="$DISK_GB" \
    --service-account="$SA" \
    --labels="app=sovereign,owner=vault"
  steps+=("configs.create")
fi

# Optional receipt emission
if [[ "${RECEIPT}" == "true" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "${RECEIPTS_DIR}"
  out="${RECEIPTS_DIR}/${RECEIPT_PREFIX}-${ts}.json"
  if command -v jq >/dev/null 2>&1; then
    tmpsteps="${RECEIPTS_DIR}/.steps.$$"; printf '%s\n' "${steps[@]}" | jq -R . | jq -s . >"$tmpsteps"
    jq -n \
      --arg kind "workstation.config" \
      --arg ts "$ts" \
      --arg track "$GCLOUD_WS_TRACK" \
      --arg project "${PROJECT_ID:-}" \
      --arg region "$REGION" \
      --arg cluster "$CLUSTER_ID" \
      --arg config "$CONFIG_ID" \
      --arg network_input "$NETWORK" \
      --arg network_full "$NETWORK_FULL" \
      --arg subnetwork_input "$SUBNETWORK" \
      --arg subnetwork_full "${SUBNETWORK_FULL:-}" \
      --argjson existed_cluster "$existed_cluster" \
      --argjson existed_config "$existed_config" \
      --slurpfile steps "$tmpsteps" \
      '{kind:$kind, ts:$ts, track:$track, project:$project, region:$region,
        cluster:$cluster, config:$config,
        network:{input:$network_input, full:$network_full},
        subnetwork:{input:$subnetwork_input, full:$subnetwork_full},
        existed:{cluster:$existed_cluster, config:$existed_config},
        steps:$steps[0], status:"ok"}' > "$out.tmp"
    rm -f "$tmpsteps"
    if "$VALIDATOR" "$out.tmp"; then
      mv "$out.tmp" "$out"
      echo "🧾 Config receipt: $out"
    else
      echo "✖ invalid receipt, not written"
      rm -f "$out.tmp"
      exit 2
    fi
  else
    echo "⚠ jq not found; skipping config receipt." >&2
  fi
fi

# Requires: yq, envsubst

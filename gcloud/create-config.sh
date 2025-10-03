#!/usr/bin/env bash
set -euo pipefail
. ./.env 2>/dev/null || true
: "${PROJECT_ID:?}"; : "${REGION:?}"; : "${WORKSTATION_CLUSTER:?}"; : "${WORKSTATION_CONFIG:?}"

gcloud config set project "$PROJECT_ID"
gcloud services enable workstations.googleapis.com

# cluster (idempotent)
gcloud workstations clusters create "$WORKSTATION_CLUSTER" \
  --region "$REGION" \
  --network=default --subnetwork=default --async || true

# workstation config (base editor, SA + disks from YAML)
SA=$(envsubst < workstation/config.yaml | yq '.service_account' -r)
CPU=$(envsubst < workstation/config.yaml | yq '.machine.cpu' -r)
MEM=$(envsubst < workstation/config.yaml | yq '.machine.memory_gb' -r)
DISK=$(envsubst < workstation/config.yaml | yq '.machine.disk_gb' -r)
TYPE=$(envsubst < workstation/config.yaml | yq '.machine.disk_type' -r)

gcloud workstations configs create "$WORKSTATION_CONFIG" \
  --cluster="$WORKSTATION_CLUSTER" --region="$REGION" \
  --machine-type=standard-$CPU --display-name="sovereign" \
  --persistent-disk=$DISK --pd-disk-type=$TYPE \
  --service-account="$SA" \
  --labels="app=sovereign,owner=vault" \
  --container-repository=WORKSTATIONS

# Requires yq (sudo snap install yq or brew install yq)
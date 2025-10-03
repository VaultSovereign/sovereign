#!/usr/bin/env bash
set -euo pipefail
. ./.env 2>/dev/null || true
: "${PROJECT_ID:?}"; : "${REGION:?}"; : "${WORKSTATION_CLUSTER:?}"; : "${WORKSTATION_CONFIG:?}"; : "${WORKSTATION_ID:?}"

gcloud workstations workstations create "$WORKSTATION_ID" \
  --cluster="$WORKSTATION_CLUSTER" --config="$WORKSTATION_CONFIG" --region="$REGION"

URL=$(gcloud workstations workstations describe "$WORKSTATION_ID" --cluster="$WORKSTATION_CLUSTER" --config="$WORKSTATION_CONFIG" --region="$REGION" --format='value(uris[0])')
echo "Open: $URL"
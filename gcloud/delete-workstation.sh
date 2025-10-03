#!/usr/bin/env bash
set -euo pipefail
. ./.env 2>/dev/null || true
gcloud workstations workstations delete "$WORKSTATION_ID" --cluster="$WORKSTATION_CLUSTER" --config="$WORKSTATION_CONFIG" --region="$REGION" --quiet || true
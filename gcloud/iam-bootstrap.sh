#!/usr/bin/env bash
set -euo pipefail
: "${PROJECT_ID:?}"; : "${DEPLOYER_SA:?}"; : "${PROXY_SA:?}"; : "${PUBLISHER_SA:?}"; : "${SCHEDULER_SA:?}"

mk(){ gcloud iam service-accounts create "$1" --display-name="$2" || true; }

mk "$DEPLOYER_SA" "VaultMesh Deployer"
mk "$PROXY_SA" "AI Companion Proxy"
mk "$PUBLISHER_SA" "Meta Publisher"
mk "$SCHEDULER_SA" "Scheduler"

# Deployer perms (trim if you want)
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$DEPLOYER_SA@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/run.admin"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$DEPLOYER_SA@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$DEPLOYER_SA@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/iam.serviceAccountTokenCreator"

# Proxy runtime minimal
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$PROXY_SA@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/iam.serviceAccountTokenCreator"

echo "IAM bootstrap done."
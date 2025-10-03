# ⚙️ GitHub Actions Setup for Guardian Drill

This guide shows how to configure automated daily drills using GitHub Actions with Workload Identity Federation (no service account keys required).

---

## Overview

The Guardian Drill workflow runs daily at 07:00 UTC and:
1. Authenticates to Google Cloud via Workload Identity
2. Runs `make drill`
3. Commits receipts and Merkle roots
4. Creates an issue if the drill fails

---

## Prerequisites

- Google Cloud project with Workload Identity Pool configured
- GitHub repository secrets configured
- Service account with appropriate permissions

---

## Setup Steps

### 1. Create Workload Identity Pool

```bash
# Set variables
export PROJECT_ID="vaultmesh-473618"
export POOL_NAME="github-actions-pool"
export PROVIDER_NAME="github-provider"
export REPO="VaultSovereign/sovereign"

# Enable required APIs
gcloud services enable iamcredentials.googleapis.com
gcloud services enable sts.googleapis.com

# Create Workload Identity Pool
gcloud iam workload-identity-pools create "${POOL_NAME}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_NAME}" \
  --location="global" \
  --workload-identity-pool="${POOL_NAME}" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" \
  --attribute-condition="assertion.repository=='${REPO}'"
```

### 2. Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-actions-drill \
  --display-name="GitHub Actions Guardian Drill"

# Bind minimal permissions
export SA_EMAIL="github-actions-drill@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.workloadIdentityUser"

# Allow GitHub Actions to impersonate this SA
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${REPO}"
```

### 3. Get Workload Identity Provider Resource Name

```bash
gcloud iam workload-identity-pools providers describe "${PROVIDER_NAME}" \
  --location="global" \
  --workload-identity-pool="${POOL_NAME}" \
  --format="value(name)"
```

Copy the output (format: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_NAME/providers/PROVIDER_NAME`)

### 4. Configure GitHub Secrets

Go to your repository settings → Secrets and variables → Actions → New repository secret

Add the following secrets:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload Identity Provider resource name | `projects/123456/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | Service account email | `github-actions-drill@vaultmesh-473618.iam.gserviceaccount.com` |
| `GCP_PROJECT_ID` | Google Cloud project ID | `vaultmesh-473618` |
| `GCP_REGION` | Primary region | `europe-west1` |
| `CF_API_TOKEN` | Cloudflare API token (optional) | `your-cloudflare-token` |

### 5. Test the Workflow

Trigger manually to test:

1. Go to **Actions** tab in GitHub
2. Select **Guardian Drill** workflow
3. Click **Run workflow**
4. Select branch (main)
5. Click **Run workflow**

Check the logs to verify:
- ✅ Authentication successful
- ✅ Drill runs without errors
- ✅ Receipts committed
- ✅ Push successful

---

## Workflow Behavior

### Success Case
- Drill passes all checks
- Receipt JSON created
- Merkle root computed
- Files committed with message: `drill: Daily receipts for YYYY-MM-DD`
- Push to main branch

### Failure Case
- Drill fails one or more checks
- Receipt still created (captures failure state)
- Files committed
- GitHub issue created with:
  - Failure details
  - Link to workflow run
  - Security checklist
  - Label: `guardian-drill`, `security`, `automated`

### Schedule
- **Daily:** 07:00 UTC
- **Manual:** Via Actions tab
- **Can be adjusted:** Edit `.github/workflows/drill.yml` cron expression

---

## Monitoring

### View Recent Drills
```bash
# List recent receipts
ls -lt workstation/receipts/drill-*.json | head -10

# Check today's Merkle root
cat workstation/receipts/root-$(date -u +%F).json
```

### View Workflow Runs
- Go to **Actions** tab in GitHub
- Filter by **Guardian Drill** workflow
- Check run history and logs

### Check for Issues
- Go to **Issues** tab
- Filter by label: `guardian-drill`
- Review any automated failure reports

---

## Troubleshooting

### Authentication Fails

**Error:** `Failed to generate Google Cloud access token`

**Fix:**
```bash
# Verify Workload Identity binding
gcloud iam service-accounts get-iam-policy "${SA_EMAIL}"

# Ensure principal is correct
# Should see: principalSet://iam.googleapis.com/projects/.../
```

### Drill Checks Fail

**Error:** `Drill returned non-zero exit code`

**Fix:**
1. Run drill locally: `make drill`
2. Check which check failed in receipt JSON
3. Fix underlying issue (ADC, tools, etc.)

### Git Push Fails

**Error:** `Permission denied (push)`

**Fix:**
1. Check workflow permissions in `.github/workflows/drill.yml`
2. Verify `contents: write` is set
3. Check branch protection rules in repo settings

### No Receipts Committed

**Error:** Workflow completes but no commit

**Fix:**
- Check if drill actually ran
- Verify `workstation/receipts/` directory exists
- Check git status in workflow logs

---

## Security Considerations

### Workload Identity Benefits
- ✅ **No service account keys** stored in GitHub
- ✅ **Automatic key rotation** via OIDC tokens
- ✅ **Scoped to specific repo** via attribute conditions
- ✅ **Auditable** via Cloud Audit Logs

### Permissions Review
The `github-actions-drill` SA should have minimal permissions:
- `roles/iam.workloadIdentityUser` (for authentication)
- Additional roles as needed for drill checks

Audit monthly:
```bash
gcloud projects get-iam-policy "${PROJECT_ID}" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-drill@*"
```

### Secret Rotation
- **Workload Identity:** Automatic via OIDC
- **CF_API_TOKEN:** Rotate every 30 days
- **Review GitHub secrets:** Quarterly audit

---

## Advanced Configuration

### Run on Pull Requests
Add to workflow trigger:
```yaml
on:
  pull_request:
    branches: [ main ]
```

### Notify on Failure
Add Slack notification:
```yaml
- name: Notify Slack
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "🚨 Guardian Drill failed: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
      }
```

### Multiple Drills
Run different drills for different environments:
```yaml
strategy:
  matrix:
    environment: [dev, staging, prod]
```

---

## Reference

- **Workflow file:** `.github/workflows/drill.yml`
- **Workload Identity docs:** https://cloud.google.com/iam/docs/workload-identity-federation
- **GitHub Actions:** https://docs.github.com/actions

---

**VaultMesh — Earth's Civilization Ledger**  
Automated drills prove sovereignty daily ⚔️
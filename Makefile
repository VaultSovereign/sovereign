-include .env

.PHONY: gcloud-iam gcloud-config gcloud-workstation gcloud-workstation-open gcloud-workstation-delete gcloud-preflight gcloud-preflight-receipt gcloud-config-receipt gcloud-workstation-receipt gcloud-workstation-delete-receipt ledger-compact ledger-compact-dryrun ledger-verify find-bug fix-bug find-bug-list find-bug-choose fix-all fix-all-dry fix-all-preview-receipt fix-all-receipt ledger-maintain ledger-maintain-preview ledger-maintain-receipt ledger-maintain-preview-receipt ledger-maintain-strict ledger-maintain-preview-strict receipts-validate receipts-validate-all drill local

gcloud-iam:
	@bash gcloud/iam-bootstrap.sh

gcloud-config:
	@bash gcloud/create-config.sh
gcloud-config-receipt:
	@RECEIPT=true RECEIPTS_DIR=$${RECEIPTS_DIR:-workstation/receipts} bash gcloud/create-config.sh

gcloud-workstation:
	@bash gcloud/create-workstation.sh
gcloud-workstation-receipt:
	@RECEIPT=true RECEIPTS_DIR=$${RECEIPTS_DIR:-workstation/receipts} bash gcloud/create-workstation.sh

# Print access URL (no create/start side effects)
gcloud-workstation-open:
	@PROJECT_ID=$${PROJECT_ID} REGION=$${REGION} CLUSTER_ID=$${CLUSTER_ID} CONFIG_ID=$${CONFIG_ID} WORKSTATION_ID=$${WORKSTATION_ID} bash -c '\
	set -euo pipefail; \
	if gcloud workstations --help >/dev/null 2>&1; then TRACK=""; elif gcloud beta workstations --help >/dev/null 2>&1; then TRACK="beta "; else TRACK="alpha "; fi; \
	if gcloud $${TRACK}workstations describe "$${WORKSTATION_ID:-sovereign-dev}" --cluster="$${CLUSTER_ID:-g-forge}" --config="$${CONFIG_ID:-config-mgalrsbs}" --region="$${REGION:-europe-west3}" >/dev/null 2>&1; then \
	  host=$$(gcloud $${TRACK}workstations describe "$${WORKSTATION_ID:-sovereign-dev}" --cluster="$${CLUSTER_ID:-g-forge}" --config="$${CONFIG_ID:-config-mgalrsbs}" --region="$${REGION:-europe-west3}" --format="value(host)" || true); \
	  if [ -n "$$host" ]; then echo "https://$$host"; else echo "Open via Cloud Console (Workstations → region/cluster/workstation)"; fi; \
	else echo "Workstation not found. Run: make gcloud-workstation"; fi'

# Delete workstation (idempotent; set FORCE=true to skip prompt)
gcloud-workstation-delete:
	@FORCE=$${FORCE} STOP_FIRST=$${STOP_FIRST} PROJECT_ID=$${PROJECT_ID} REGION=$${REGION} CLUSTER_ID=$${CLUSTER_ID} CONFIG_ID=$${CONFIG_ID} WORKSTATION_ID=$${WORKSTATION_ID} bash gcloud/delete-workstation.sh
gcloud-workstation-delete-receipt:
	@RECEIPT=true RECEIPTS_DIR=$${RECEIPTS_DIR:-workstation/receipts} FORCE=$${FORCE} STOP_FIRST=$${STOP_FIRST} PROJECT_ID=$${PROJECT_ID} REGION=$${REGION} CLUSTER_ID=$${CLUSTER_ID} CONFIG_ID=$${CONFIG_ID} WORKSTATION_ID=$${WORKSTATION_ID} bash gcloud/delete-workstation.sh

ledger-compact:
	@RECEIPTS_DIR=$${RECEIPTS_DIR:-workstation/receipts} DAILY_DIR=$${DAILY_DIR:-workstation/receipts/daily} KEEP=$${KEEP:-5} bash scripts/ledger-compact.sh

ledger-compact-dryrun:
	@RECEIPTS_DIR=$${RECEIPTS_DIR:-workstation/receipts} DAILY_DIR=$${DAILY_DIR:-workstation/receipts/daily} KEEP=$${KEEP:-5} DRY_RUN=true VERBOSE=$${VERBOSE:-true} bash scripts/ledger-compact.sh

# Recompute and verify daily roots. Set DAY=YYYYMMDD to verify a single day.
ledger-verify:
	@RECEIPTS_DIR=$${RECEIPTS_DIR:-workstation/receipts} DAILY_DIR=$${DAILY_DIR:-workstation/receipts/daily} DAY=$${DAY} STRICT=$${STRICT:-false} bash scripts/ledger-verify.sh

find-bug:
	@bash scripts/find-fix-bug.sh "$(FILE)"

fix-bug: find-bug
	@true

find-bug-list:
	@bash scripts/find-fix-bug.sh --list "$(FILE)"
find-bug-choose:
	@bash scripts/find-fix-bug.sh --choose "$(FILE)"

fix-all:
	@NON_VENDOR_ONLY=$${NON_VENDOR_ONLY:-true} SEARCH_ROOT=$${SEARCH_ROOT:-.} JOBS=$${JOBS:-} bash scripts/find-fix-all.sh --include "$${INCLUDE:-}" --exclude "$${EXCLUDE:-}"

fix-all-dry:
	@NON_VENDOR_ONLY=$${NON_VENDOR_ONLY:-true} SEARCH_ROOT=$${SEARCH_ROOT:-.} JOBS=$${JOBS:-} DRY_RUN=true bash scripts/find-fix-all.sh --include "$${INCLUDE:-}" --exclude "$${EXCLUDE:-}" --dry-run

fix-all-preview-receipt:
	@RECEIPT=true NON_VENDOR_ONLY=$${NON_VENDOR_ONLY:-true} SEARCH_ROOT=$${SEARCH_ROOT:-.} JOBS=$${JOBS:-} DRY_RUN=true bash scripts/find-fix-all.sh --include "$${INCLUDE:-}" --exclude "$${EXCLUDE:-}" --dry-run

fix-all-receipt:
	@RECEIPT=true NON_VENDOR_ONLY=$${NON_VENDOR_ONLY:-true} SEARCH_ROOT=$${SEARCH_ROOT:-.} JOBS=$${JOBS:-} bash scripts/find-fix-all.sh --include "$${INCLUDE:-}" --exclude "$${EXCLUDE:-}"

.PHONY: ledger-maintain ledger-maintain-preview ledger-maintain-receipt ledger-maintain-preview-receipt
# Apply: compact → verify → fix-all (with receipts for sub-steps)
ledger-maintain:
	@DRY_RUN=false RECEIPT=false STRICT=$${STRICT:-false} KEEP=$${KEEP:-5} VERBOSE=$${VERBOSE:-false} INCLUDE="$${INCLUDE:-}" EXCLUDE="$${EXCLUDE:-}" NON_VENDOR_ONLY=$${NON_VENDOR_ONLY:-true} JOBS=$${JOBS:-} SEARCH_ROOT=$${SEARCH_ROOT:-.} bash scripts/ledger-maintain.sh

# Preview only: dry-run compact + fix-all preview receipt + verify
ledger-maintain-preview:
	@DRY_RUN=true RECEIPT=false STRICT=$${STRICT:-false} KEEP=$${KEEP:-5} VERBOSE=$${VERBOSE:-true} INCLUDE="$${INCLUDE:-}" EXCLUDE="$${EXCLUDE:-}" NON_VENDOR_ONLY=$${NON_VENDOR_ONLY:-true} JOBS=$${JOBS:-} SEARCH_ROOT=$${SEARCH_ROOT:-.} bash scripts/ledger-maintain.sh

# Apply with top-level maintenance receipt
ledger-maintain-receipt:
	@DRY_RUN=false RECEIPT=true STRICT=$${STRICT:-false} KEEP=$${KEEP:-5} VERBOSE=$${VERBOSE:-false} INCLUDE="$${INCLUDE:-}" EXCLUDE="$${EXCLUDE:-}" NON_VENDOR_ONLY=$${NON_VENDOR_ONLY:-true} JOBS=$${JOBS:-} SEARCH_ROOT=$${SEARCH_ROOT:-.} bash scripts/ledger-maintain.sh

# Preview with top-level maintenance receipt
ledger-maintain-preview-receipt:
	@DRY_RUN=true RECEIPT=true STRICT=$${STRICT:-false} KEEP=$${KEEP:-5} VERBOSE=$${VERBOSE:-true} INCLUDE="$${INCLUDE:-}" EXCLUDE="$${EXCLUDE:-}" NON_VENDOR_ONLY=$${NON_VENDOR_ONLY:-true} JOBS=$${JOBS:-} SEARCH_ROOT=$${SEARCH_ROOT:-.} bash scripts/ledger-maintain.sh

ledger-maintain-strict:
	@STRICT=true $(MAKE) ledger-maintain

ledger-maintain-preview-strict:
	@STRICT=true $(MAKE) ledger-maintain-preview

receipts-validate:
	@bash scripts/receipt-validate.sh "$${FILE}"

receipts-validate-all:
	@bash -c 'set -euo pipefail; shopt -s nullglob; files=(workstation/receipts/*.json workstation/receipts/daily/*.json); for f in "${files[@]}"; do [ -f "$$f" ] && bash scripts/receipt-validate.sh "$$f"; done; echo "✔ all receipts valid"'

.PHONY: ci-ledger
ci-ledger:
	@STRICT=true KEEP=$${KEEP:-3} VERBOSE=$${VERBOSE:-true} $(MAKE) ledger-maintain-preview
	@$(MAKE) receipts-validate-all

# Preflight: ADC, APIs, region probe, quotas, network (optional)
gcloud-preflight:
	@AUTO_ENABLE=$${AUTO_ENABLE} PROJECT_ID=$${PROJECT_ID} REGION=$${REGION} NETWORK=$${NETWORK} SUBNETWORK=$${SUBNETWORK} bash gcloud/preflight.sh

# Preflight with JSON receipt emission
gcloud-preflight-receipt:
	@RECEIPT=true RECEIPTS_DIR=$${RECEIPTS_DIR:-workstation/receipts} AUTO_ENABLE=$${AUTO_ENABLE} PROJECT_ID=$${PROJECT_ID} REGION=$${REGION} NETWORK=$${NETWORK} SUBNETWORK=$${SUBNETWORK} bash gcloud/preflight.sh

drill:
	@bash workstation/drills/guardian-drill.sh

local:
	@bash local/install.sh

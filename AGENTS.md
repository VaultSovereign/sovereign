# Repository Guidelines

## Project Structure & Module Organization
- `gcloud/` – Cloud Workstations provisioning (create/delete/config, IAM bootstrap).
- `workstation/` – Single source of truth: `config.yaml`, `startup.sh`, `poststart.sh`, `receipts/` (drill + daily roots).
- `scripts/` – Shared maintenance: `ledger-*`, `find-fix-*`, `receipt-validate.sh`.
- `docs/` – Runbooks, security notes, schemas; `README.md` has command overview.
- `devcontainer/` – Containerized dev environment; `local/` – laptop bootstrap.
- `githooks/` – Optional `pre-commit`.
- `.env.example` – copy to `.env` for local overrides.

## Build, Test, and Development Commands
- `make gcloud-iam` – create/verify least‑privilege SAs and roles.
- `make gcloud-config` | `make gcloud-workstation` – ensure config, then create/start workstation.
- `make gcloud-workstation-open` – print access URL (no side effects).
- `make ledger-maintain-preview` | `make ledger-maintain` – compact → verify → fix‑all (preview/apply).
- `make receipts-validate-all` – validate all JSON receipts.
- `make fix-all` | `make fix-all-dry` – run linters/formatters across repo.

## Coding Style & Naming Conventions
- Shell: `#!/usr/bin/env bash` + `set -euo pipefail`; 2‑space indent; hyphen‑case filenames (e.g., `ledger-verify.sh`).
- Vars: environment in `UPPER_SNAKE_CASE`; functions/locals in `lower_snake_case`.
- Formatters/Linters: `shellcheck`, `shfmt`, `eslint`/`prettier`/`tsc` (via `pnpm`), `jq`, `yq`, `cargo fmt`. Example: `make fix-all`.

## Testing Guidelines
- This repo is ops‑focused; “tests” are receipts and validations.
- Local check (run before PR): `STRICT=true KEEP=3 VERBOSE=true make ledger-maintain-preview` and `make receipts-validate-all` (both must pass).
- Receipt locations: `workstation/receipts/*.json`; daily roots in `workstation/receipts/daily/*.json` (e.g., `root-YYYY-MM-DD.json`).
- CI mirrors this flow: `.github/workflows/ledger-ci.yml` runs preview (strict) then validates on push/PR.

## Commit & Pull Request Guidelines
- Use Conventional Commits (e.g., `feat:`, `fix:`, `docs:`, `ci:`, `security:`). Example from history: `docs: add comprehensive ecosystem map`.
- Include: description, commands run, relevant env, linked issues, sample logs/receipts.
- Do not commit secrets; update docs when changing behavior or flags.

## Pre-commit Hook
- Enable hooks (recommended): `git config core.hooksPath githooks`.
  - Alternative: `ln -sf ../../githooks/pre-commit .git/hooks/pre-commit`.
- The hook runs: `STRICT=true KEEP=${KEEP:-3} VERBOSE=${VERBOSE:-true} make ledger-maintain-preview` then `make receipts-validate-all`.
- Commit only when green; fix via `make fix-all`.

## Security & Configuration Tips
- Prefer ADC; no key files. Configure `.env` (`PROJECT_ID`, `REGION`, etc.).
- Maintain least‑privilege SAs; for IAM changes, run `make gcloud-preflight` and include rationale.

## Agent-Specific Instructions
- Prefer Makefile targets over ad‑hoc `gcloud` calls; keep diffs minimal and scoped.
- Never edit receipts by hand—use the provided targets/scripts.

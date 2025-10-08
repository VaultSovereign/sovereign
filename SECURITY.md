# Security Policy

## Reporting a Vulnerability
Email **security@vaultmesh.org** with:
- description, impact, repro steps/PoC, suggested mitigation
- PGP available on request; we support coordinated disclosure.

**SLO:** acknowledge within **72h**; fix within **14 days** where feasible.

## Scope & Support
We maintain the **main** branch and the latest tagged release line.
Backports are performed selectively for critical issues.

## Dependency Hygiene
Automated checks (Dependabot, OpenSSF Scorecard, Dependency Review) are enforced.
SBOMs (CycloneDX) are generated on pushes to main and releases.

## Ledger & Attestation
Security-relevant changes should produce receipts and be captured in daily roots.
Where possible, artifacts are signed (GPG/KMS) and published by workflow.

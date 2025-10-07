#!/usr/bin/env bash
# Tiny covenant test for VaultMesh ledger: modern verify, optional legacy verify,
# and invariants for domain metadata, content-addressed proofs, and payload integrity.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
DAILY_DIR="${DAILY_DIR:-$RECEIPTS_DIR/daily}"
PROOFS_DIR="${PROOFS_DIR:-$DAILY_DIR/proofs}"
LEDGER_DOMAIN_VERSION="${LEDGER_DOMAIN_VERSION:-1}"
SELFTEST_PROOFS="${SELFTEST_PROOFS:-3}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "✖ missing dependency: $1" >&2
    exit 1
  }
}

need jq
need base64
need wc
need tr
need python3

if ! command -v openssl >/dev/null 2>&1; then
  echo "✖ openssl required" >&2
  exit 1
fi
if ! command -v b3sum >/dev/null 2>&1; then
  echo "• b3sum not found — BLAKE3 checks will be skipped (install 'b3sum' for full coverage)" >&2
fi

say() {
  printf "%b %s\n" "$1" "$2"
}

hash_bytes() {
  local algo="$1"
  local file="$2"
  case "$algo" in
    BLAKE3-256)
      if command -v b3sum >/dev/null 2>&1; then
        b3sum -l 256 "$file" | awk '{print $1}'
      else
        echo "SKIP_BLAKE3"
      fi
      ;;
    SHA256)
      openssl dgst -sha256 "$file" | awk '{print $2}'
      ;;
    *)
      echo "UNKNOWN_ALGO"
      ;;
  esac
}

leaf_hash_from_canonical() {
  local algo="$1"
  local canonical="$2"
  local tmp
  tmp="$(mktemp)"
  python3 - "$canonical" "$tmp" <<'PY'
import sys
from pathlib import Path
src, out = Path(sys.argv[1]), Path(sys.argv[2])
data = src.read_bytes()
out.write_bytes(bytes.fromhex("00") + data)
PY
  local digest
  digest="$(hash_bytes "$algo" "$tmp")"
  rm -f "$tmp"
  echo "$digest"
}

printf '%s\n' '== 🧪 Ledger covenant self-test =='
printf '%s\n' "-- root: $ROOT_DIR"
printf '%s\n' "-- receipts: $RECEIPTS_DIR"

say "▶" "make receipts-validate-all"
make receipts-validate-all >/dev/null

say "▶" "KEEP=${KEEP:-5} VERBOSE=true make ledger-compact-dryrun"
KEEP="${KEEP:-5}" VERBOSE=true make ledger-compact-dryrun >/dev/null

say "▶" "STRICT=false make ledger-verify (modern)"
STRICT=false make ledger-verify >/dev/null

if compgen -G "workstation/receipts/fixtures/legacy/*/*.json" >/dev/null; then
  say "▶" "legacy fixtures detected → running legacy verify (STRICT=true)"
  RECEIPTS_DIR="workstation/receipts/fixtures/legacy" STRICT=true make ledger-verify >/dev/null
else
  say "•" "no legacy fixtures; legacy verify skipped (as designed)"
fi

modern_roots=0
shopt -s nullglob
for root_file in "$DAILY_DIR"/*.json; do
  if jq -e '.canonicalization=="JCS-RFC8785"' "$root_file" >/dev/null 2>&1; then
    modern_roots=$((modern_roots + 1))
    jq -e --arg v "$LEDGER_DOMAIN_VERSION" '
      .timezone=="UTC" and
      .order=="asc-leaf-hash" and
      .domain_separation.leaf=="00" and
      .domain_separation.node=="01" and
      ( .domain_version|tostring ) == $v
    ' "$root_file" >/dev/null || {
      say "✖" "[domain] invariant failed in $root_file"
      exit 1
    }
  fi
done

if (( modern_roots > 0 )); then
  say "✔" "[domain] invariants hold in $modern_roots modern root(s)"
else
  say "•" "no modern roots found to check"
fi

latest_day=""
if [ -d "$PROOFS_DIR" ]; then
  latest_day="$(ls -1 "$PROOFS_DIR" 2>/dev/null | sort -r | head -n 1 || true)"
fi

if [ -n "$latest_day" ] && [ -d "$PROOFS_DIR/$latest_day" ]; then
  say "▶" "spot-checking up to $SELFTEST_PROOFS proof(s) in $PROOFS_DIR/$latest_day"
  count=0
  shopt -s nullglob
  proofs=("$PROOFS_DIR/$latest_day"/*.json)
  for proof in "${proofs[@]}"; do
    if [ "$count" -ge "$SELFTEST_PROOFS" ]; then
      break
    fi
    base="$(basename "$proof" .json)"
    jq -e --arg h "$base" '.leaf_hash==$h' "$proof" >/dev/null || {
      say "✖" "[proof] filename != leaf_hash: $proof"
      exit 1
    }

    algo="$(jq -r '.hash_algo' "$proof")"
    canon="$(jq -r '.canonicalization' "$proof")"
    domain_ver="$(jq -r '(.domain_version|tostring) // ""' "$proof")"
    [ "$canon" = "JCS-RFC8785" ] || {
      say "✖" "[proof] canon mismatch in $proof"
      exit 1
    }
    [ "$domain_ver" = "$LEDGER_DOMAIN_VERSION" ] || {
      say "✖" "[proof] domain_version mismatch in $proof"
      exit 1
    }

    b64="$(jq -r '.receipt_b64' "$proof")"
    want_len="$(jq -r '.receipt_len' "$proof")"
    want_payload_hash="$(jq -r '.receipt_hash' "$proof")"
    tmp="$(mktemp)"
    if ! printf '%s' "$b64" | base64 -d > "$tmp" 2>/dev/null; then
      rm -f "$tmp"
      say "✖" "[proof] base64 decode failed: $proof"
      exit 1
    fi
    have_len="$(wc -c < "$tmp" | tr -d '[:space:]')"
    [ "$have_len" = "$want_len" ] || {
      rm -f "$tmp"
      say "✖" "[proof] length mismatch in $proof"
      exit 1
    }
    have_payload_hash="$(hash_bytes "$algo" "$tmp")"
    if [ "$have_payload_hash" = "SKIP_BLAKE3" ]; then
      say "•" "[proof] b3sum unavailable; skipping BLAKE3 hash checks for $proof"
    else
      [ "$have_payload_hash" = "$want_payload_hash" ] || {
        rm -f "$tmp"
        say "✖" "[proof] payload hash mismatch in $proof"
        exit 1
      }
      have_leaf_hash="$(leaf_hash_from_canonical "$algo" "$tmp")"
      if [ "$have_leaf_hash" = "SKIP_BLAKE3" ]; then
        say "•" "[proof] b3sum unavailable; skipping BLAKE3 leaf check for $proof"
      else
        [ "$have_leaf_hash" = "$base" ] || {
          rm -f "$tmp"
          say "✖" "[proof] leaf_hash mismatch in $proof"
          exit 1
        }
      fi
    fi
    rm -f "$tmp"

    count=$((count + 1))
  done
  say "✔" "[proofs] $count proof(s) passed content-address + payload integrity"
else
  say "•" "no proofs directory found yet; run a non-dry compaction to generate proofs"
fi

say "✅" "ledger self-test passed"

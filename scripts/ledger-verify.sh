#!/usr/bin/env bash
set -euo pipefail
# Verify daily Merkle roots produced by ledger-compact.
# Supports both the legacy (pre-domain-separation) and modern receipts.
#
# Env:
#   RECEIPTS_DIR  (default: workstation/receipts)
#   DAILY_DIR     (default: $RECEIPTS_DIR/daily)
#   PROOFS_DIR    (default: $DAILY_DIR/proofs)
#   DAY           (optional: YYYYMMDD; if unset, verify all days found)
#   STRICT        (default: false) → when true, fail if any day's supporting data is missing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/ledger.sh"

RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
DAILY_DIR="${DAILY_DIR:-$RECEIPTS_DIR/daily}"
PROOFS_DIR="${PROOFS_DIR:-$DAILY_DIR/proofs}"
DAY="${DAY:-}"
STRICT="${STRICT:-false}"

mkdir -p "$RECEIPTS_DIR" "$DAILY_DIR" "$PROOFS_DIR"

say() { printf "%b %s\n" "$1" "$2"; }

legacy_hash_pair() {
  local left="$1" right="$2" tmp digest
  tmp="$(mktemp)"
  ledger_require_python
  python3 - "$left" "$right" "$tmp" <<'PY'
import binascii
import sys
from pathlib import Path
left, right, path = sys.argv[1], sys.argv[2], Path(sys.argv[3])
with path.open('wb') as fh:
    fh.write(binascii.unhexlify(left))
    fh.write(binascii.unhexlify(right))
PY
  digest="$(ledger_hash_file "$tmp")"
  rm -f "$tmp"
  echo "$digest"
}

legacy_merkle() {
  local -a level=("$@") next=()
  ((${#level[@]})) || { echo ""; return; }
  while ((${#level[@]} > 1)); do
    next=()
    local size=${#level[@]}
    for ((i=0; i<size; i+=2)); do
      local left="${level[i]}"
      local right="${level[i+1]:-${level[i]}}"
      next+=("$(legacy_hash_pair "$left" "$right")")
    done
    level=("${next[@]}")
  done
  echo "${level[0]}"
}

apply_proof_path() {
  local leaf_hash="$1" proof_file="$2"
  local current="$leaf_hash"
  while IFS= read -r step; do
    local dir="$(jq -r '.dir' <<<"$step")"
    local sibling="$(jq -r '.hash' <<<"$step")"
    case "$dir" in
      right)
        current="$(ledger_hash_pair "$current" "$sibling")"
        ;;
      left)
        current="$(ledger_hash_pair "$sibling" "$current")"
        ;;
      *)
        echo ""; return 1
        ;;
    esac
  done < <(jq -c '.path[]?' "$proof_file")
  echo "$current"
}

decode_base64_to_file() {
  local data="$1" out="$2"
  ledger_require_python
  python3 - "$data" "$out" <<'PY'
import base64
import sys
from pathlib import Path
data = sys.argv[1]
path = Path(sys.argv[2])
path.write_bytes(base64.b64decode(data))
PY
}

set_hash_from_algo() {
  local algo="$1"
  case "$algo" in
    BLAKE3-256)
      LEDGER_HASH="blake3"
      ;;
    SHA256)
      LEDGER_HASH="sha256"
      ;;
    *)
      return 1
      ;;
  esac
  return 0
}

verify_legacy_day() {
  local day="$1" meta="$2"
  local stored_root="$(jq -r '.root' "$meta")"
  local algo="$(jq -r '.algo // "BLAKE3-256"' "$meta")"
  local prev_hash="$LEDGER_HASH"
  if ! set_hash_from_algo "$algo"; then
    say "✖" "[$day] unsupported legacy algo: $algo"
    LEDGER_HASH="$prev_hash"
    return 1
  fi
  mapfile -t listed < <(jq -r '.files[]' "$meta")
  actual_files=()
  pattern="*-${day}T*Z.json"
  while IFS= read -r f; do actual_files+=("$(basename "$f")"); done < <(find "$RECEIPTS_DIR" -maxdepth 1 -type f -name "$pattern" | sort -r)
  declare -A seen=()
  merged=()
  local fails=0
  local missing=0
  for f in "${listed[@]}"; do
    if [[ -f "$RECEIPTS_DIR/$f" ]]; then
      seen["$f"]=1
      merged+=("$f")
    else
      if [[ "$STRICT" == "true" ]]; then
        say "✖" "[$day] legacy receipt missing: $f"
        fails=$((fails+1))
      else
        say "⚠" "[$day] legacy receipt missing (ignored in non-STRICT mode): $f"
        missing=1
      fi
    fi
  done
  for f in "${actual_files[@]}"; do
    [[ -n "${seen[$f]:-}" ]] || merged+=("$f")
  done
  digests=()
  for f in "${merged[@]}"; do digests+=("$(ledger_hash_file "$RECEIPTS_DIR/$f")"); done
  if ((fails > 0)); then
    LEDGER_HASH="$prev_hash"
    return 1
  fi
  if ((missing > 0)); then
    LEDGER_HASH="$prev_hash"
    say "*" "[$day] skipping legacy root verification (receipts missing; run STRICT=true to enforce)"
    return 0
  fi
  recomputed="$(legacy_merkle "${digests[@]}")"
  LEDGER_HASH="$prev_hash"
  if [[ "$recomputed" == "$stored_root" ]]; then
    say "✔" "[$day] legacy OK — root matches ($algo): $recomputed"
    return 0
  else
    say "✖" "[$day] legacy mismatch — stored: $stored_root  recomputed: $recomputed"
    return 1
  fi
}

verify_modern_day() {
  local day="$1" meta="$2"
  local stored_root="$(jq -r '.root' "$meta")"
  local algo="$(jq -r '.hash_algo // .algo' "$meta")"
  local canonicalization="$(jq -r '.canonicalization' "$meta")"
  local timezone="$(jq -r '.timezone // "UTC"' "$meta")"
  local order="$(jq -r '.order // empty' "$meta")"
  local inputs_digest="$(jq -r '.inputs_digest // empty' "$meta")"
  local domain_version="$(jq -r '.domain_version // empty' "$meta")"
  local domain_leaf="$(jq -r '.domain_separation.leaf // empty' "$meta")"
  local domain_node="$(jq -r '.domain_separation.node // empty' "$meta")"
  local leaf_count="$(jq -r '.leaf_count // (.files|length)' "$meta")"
  local prev_hash="$LEDGER_HASH"
  if ! set_hash_from_algo "$algo"; then
    say "✖" "[$day] unsupported hash algorithm in metadata: $algo"
    return 1
  fi

  local errors=0
  if [[ "$canonicalization" != "$LEDGER_CANONICALIZATION" ]]; then
    say "✖" "[$day] canonicalization mismatch: $canonicalization"
    errors=$((errors+1))
  fi
  if [[ "$timezone" != "UTC" ]]; then
    say "✖" "[$day] timezone mismatch: $timezone"
    errors=$((errors+1))
  fi
  if [[ "$order" != "asc-leaf-hash" ]]; then
    say "✖" "[$day] order mismatch: $order"
    errors=$((errors+1))
  fi
  if [[ -z "$domain_version" ]]; then
    say "✖" "[$day] domain version missing"
    errors=$((errors+1))
  elif [[ "$domain_version" != "$LEDGER_DOMAIN_VERSION" ]]; then
    say "✖" "[$day] domain version mismatch: $domain_version"
    errors=$((errors+1))
  fi
  if [[ "$domain_leaf" != "00" || "$domain_node" != "01" ]]; then
    say "✖" "[$day] domain separation mismatch"
    errors=$((errors+1))
  fi

  local -a nodes=()
  mapfile -t nodes < <(jq -c '.files[]' "$meta")
  local -a leaf_hashes=()
  for node in "${nodes[@]}"; do
    file="$(jq -r '.file' <<<"$node")"
    leaf_hash="$(jq -r '.leaf_hash' <<<"$node")"
    retained="$(jq -r '.retained // false' <<<"$node")"
    proof_ref="$(jq -r '.proof // empty' <<<"$node")"
    index_meta="$(jq -r '.index // empty' <<<"$node")"
    if [[ ! "$leaf_hash" =~ ^[0-9a-f]{64}$ ]]; then
      say "✖" "[$day] invalid leaf hash recorded for $file"
      errors=$((errors+1))
      continue
    fi
    if [[ "$retained" == "true" ]]; then
      if [[ ! -f "$RECEIPTS_DIR/$file" ]]; then
        if [[ "$STRICT" == "true" ]]; then
          say "✖" "[$day] retained receipt missing: $file"
          errors=$((errors+1))
        else
          say "⚠" "[$day] retained receipt missing (ignored in non-STRICT mode): $file"
        fi
        continue
      fi
      tmp_can="$(mktemp)"
      ledger_canonicalize_json "$RECEIPTS_DIR/$file" "$tmp_can"
      actual_hash="$(ledger_leaf_hash_from_canonical "$tmp_can")"
      rm -f "$tmp_can"
      if [[ "$actual_hash" != "$leaf_hash" ]]; then
        say "✖" "[$day] leaf hash mismatch for $file"
        errors=$((errors+1))
        continue
      fi
    else
      rel_path="$proof_ref"
      if [[ -z "$rel_path" ]]; then
        rel_path="proofs/$day/${leaf_hash}.json"
      fi
      proof_file="$DAILY_DIR/$rel_path"
      if [[ ! -f "$proof_file" ]]; then
        say "✖" "[$day] missing proof for pruned receipt $file"
        errors=$((errors+1))
        continue
      fi
      proof_root="$(jq -r '.root' "$proof_file")"
      proof_algo="$(jq -r '.hash_algo' "$proof_file")"
      proof_leaf="$(jq -r '.leaf_hash' "$proof_file")"
      proof_canon="$(jq -r '.canonicalization' "$proof_file")"
      proof_domain_version="$(jq -r '.domain_version // empty' "$proof_file")"
      proof_domain_leaf="$(jq -r '.domain_separation.leaf // empty' "$proof_file")"
      proof_domain_node="$(jq -r '.domain_separation.node // empty' "$proof_file")"
      proof_order="$(jq -r '.order // empty' "$proof_file")"
      proof_index="$(jq -r '.leaf_index // empty' "$proof_file")"
      proof_len="$(jq -r '.receipt_len // empty' "$proof_file")"
      proof_receipt_hash="$(jq -r '.receipt_hash // empty' "$proof_file")"
      receipt_b64="$(jq -r '.receipt_b64 // empty' "$proof_file")"
      if [[ "$proof_root" != "$stored_root" ]]; then
        say "✖" "[$day] proof root mismatch for $file"
        errors=$((errors+1))
      fi
      if [[ "$proof_algo" != "$algo" ]]; then
        say "✖" "[$day] proof hash algorithm mismatch for $file"
        errors=$((errors+1))
      fi
      if [[ "$proof_leaf" != "$leaf_hash" ]]; then
        say "✖" "[$day] proof leaf hash mismatch for $file"
        errors=$((errors+1))
      fi
      if [[ "$proof_canon" != "$canonicalization" ]]; then
        say "✖" "[$day] proof canonicalization mismatch for $file"
        errors=$((errors+1))
      fi
      if [[ -z "$proof_domain_version" ]]; then
        say "✖" "[$day] proof domain version missing for $file"
        errors=$((errors+1))
      elif [[ "$proof_domain_version" != "$LEDGER_DOMAIN_VERSION" ]]; then
        say "✖" "[$day] proof domain version mismatch for $file"
        errors=$((errors+1))
      fi
      if [[ "$proof_domain_leaf" != "00" || "$proof_domain_node" != "01" ]]; then
        say "✖" "[$day] proof domain separation mismatch for $file"
        errors=$((errors+1))
      fi
      if [[ "$proof_order" != "asc-leaf-hash" ]]; then
        say "✖" "[$day] proof order mismatch for $file"
        errors=$((errors+1))
      fi
      if [[ -n "$index_meta" && -n "$proof_index" && "$index_meta" != "$proof_index" ]]; then
        say "✖" "[$day] proof index mismatch for $file"
        errors=$((errors+1))
      fi
      if [[ -z "$proof_len" || "$proof_len" == "null" ]]; then
        say "✖" "[$day] proof missing receipt length for $file"
        errors=$((errors+1))
      fi
      if [[ -z "$proof_receipt_hash" || ! "$proof_receipt_hash" =~ ^[0-9a-f]{64}$ ]]; then
        say "✖" "[$day] proof missing receipt hash for $file"
        errors=$((errors+1))
      fi
      if [[ -z "$receipt_b64" ]]; then
        say "✖" "[$day] proof missing canonical receipt for $file"
        errors=$((errors+1))
      else
        local local_len payload_hash
        tmp_can="$(mktemp)"
        decode_base64_to_file "$receipt_b64" "$tmp_can"
        local_len="$(wc -c <"$tmp_can" | tr -d '[:space:]')"
        actual_hash="$(ledger_leaf_hash_from_canonical "$tmp_can")"
        payload_hash="$(ledger_hash_file "$tmp_can")"
        rm -f "$tmp_can"
        if [[ -n "$proof_len" && "$proof_len" != "null" && "$proof_len" != "$local_len" ]]; then
          say "✖" "[$day] proof canonical length mismatch for $file"
          errors=$((errors+1))
        fi
        if [[ "$actual_hash" != "$leaf_hash" ]]; then
          say "✖" "[$day] proof canonical payload mismatch for $file"
          errors=$((errors+1))
        fi
        if [[ -n "$proof_receipt_hash" && "$payload_hash" != "$proof_receipt_hash" ]]; then
          say "✖" "[$day] proof payload hash mismatch for $file"
          errors=$((errors+1))
        fi
      fi
      computed_root="$(apply_proof_path "$leaf_hash" "$proof_file" || echo "")"
      if [[ -z "$computed_root" || "$computed_root" != "$stored_root" ]]; then
        say "✖" "[$day] proof path invalid for $file"
        errors=$((errors+1))
      fi
    fi
    leaf_hashes+=("$leaf_hash")
  done

  if (( ${#leaf_hashes[@]} != leaf_count )); then
    say "✖" "[$day] leaf count mismatch (expected $leaf_count, have ${#leaf_hashes[@]})"
    errors=$((errors+1))
  fi

  if (( ${#leaf_hashes[@]} > 0 )); then
    recomputed="$(ledger_merkle_root "${leaf_hashes[@]}")"
    if [[ "$recomputed" != "$stored_root" ]]; then
      say "✖" "[$day] recomputed root mismatch: $recomputed vs $stored_root"
      errors=$((errors+1))
    fi
    if [[ -n "$inputs_digest" ]]; then
      digest_calc="$(printf '%s\n' "${leaf_hashes[@]}" | ledger_hex_concat_hash)"
      if [[ "$digest_calc" != "$inputs_digest" ]]; then
        say "✖" "[$day] inputs digest mismatch"
        errors=$((errors+1))
      fi
    fi
  fi

  LEDGER_HASH="$prev_hash"

  if ((errors == 0)); then
    say "✔" "[$day] OK — root matches ($algo): $stored_root"
    return 0
  fi
  return 1
}

# Collect days to verify
days=()
if [[ -n "$DAY" ]]; then
  [[ "$DAY" =~ ^[0-9]{8}$ ]] || { echo "DAY must be YYYYMMDD"; exit 2; }
  [[ -f "$DAILY_DIR/$DAY.json" ]] || { echo "No daily root file at $DAILY_DIR/$DAY.json"; exit 2; }
  days+=("$DAY")
else
  while IFS= read -r f; do
    base="$(basename "$f")"; d="${base%.json}"
    [[ "$d" =~ ^[0-9]{8}$ ]] && days+=("$d")
  done < <(find "$DAILY_DIR" -maxdepth 1 -type f -name '*.json' | sort)
fi

fails=0
for d in "${days[@]}"; do
  meta="$DAILY_DIR/$d.json"
  if jq -e '.canonicalization and .domain_separation' "$meta" >/dev/null 2>&1; then
    verify_modern_day "$d" "$meta" || fails=$((fails+1))
  else
    verify_legacy_day "$d" "$meta" || fails=$((fails+1))
  fi
done

exit $(( fails > 0 ? 1 : 0 ))

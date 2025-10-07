#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for ledger scripts: canonical JSON rendering, hashing, and Merkle math.

LEDGER_HASH="${LEDGER_HASH:-blake3}"
LEDGER_LEAF_PREFIX="00"
LEDGER_NODE_PREFIX="01"
LEDGER_CANONICALIZATION="JCS-RFC8785"
LEDGER_DOMAIN_VERSION="${LEDGER_DOMAIN_VERSION:-1}"

ledger_require_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "✖ python3 is required for ledger operations" >&2
    exit 1
  fi
}

ledger_hash_algo_name() {
  case "$LEDGER_HASH" in
    blake3|BLAKE3|BLAKE3-256)
      echo "BLAKE3-256"
      ;;
    sha256|SHA256|SHA-256)
      echo "SHA256"
      ;;
    *)
      echo "✖ unsupported LEDGER_HASH value '$LEDGER_HASH' (expected blake3 or sha256)" >&2
      exit 1
      ;;
  esac
}

ledger_hash_file() {
  local file="$1"
  case "$(ledger_hash_algo_name)" in
    BLAKE3-256)
      if command -v b3sum >/dev/null 2>&1; then
        b3sum -l 256 "$file" | awk '{print $1}'
      else
        echo "✖ b3sum is required for BLAKE3 hashing" >&2
        exit 1
      fi
      ;;
    SHA256)
      if command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $2}'
      elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
      else
        echo "✖ openssl or shasum required for SHA256 hashing" >&2
        exit 1
      fi
      ;;
  esac
}

ledger_hex_concat_hash() {
  # Hash a sequence of hex digests provided via stdin (whitespace separated/newline) by
  # concatenating their binary form and hashing the resulting bytes.
  local tmp digest
  tmp="$(mktemp)"
  ledger_require_python
  python3 - "$tmp" <<'PY'
import binascii
import sys
from pathlib import Path
hex_values = sys.stdin.read().split()
path = Path(sys.argv[1])
with path.open('wb') as fh:
    for value in hex_values:
        if value:
            fh.write(binascii.unhexlify(value))
PY
  digest="$(ledger_hash_file "$tmp")"
  rm -f "$tmp"
  echo "$digest"
}

ledger_canonicalize_json() {
  # Usage: ledger_canonicalize_json <input.json> <output.tmp>
  local input="$1" output="$2"
  ledger_require_python
  python3 - "$input" "$output" <<'PY'
import json
import sys
from pathlib import Path

def ensure_canonical(value):
    if isinstance(value, dict):
        return {k: ensure_canonical(value[k]) for k in sorted(value)}
    if isinstance(value, list):
        return [ensure_canonical(v) for v in value]
    if isinstance(value, float):
        raise SystemExit("floating point numbers are not supported in receipts")
    return value

inp = Path(sys.argv[1])
out = Path(sys.argv[2])
with inp.open('r', encoding='utf-8') as fh:
    data = json.load(fh)
canonical = ensure_canonical(data)
encoded = json.dumps(canonical, separators=(',', ':'), ensure_ascii=False)
with out.open('wb') as fh:
    fh.write(encoded.encode('utf-8'))
PY
}

ledger_leaf_hash_from_canonical() {
  local canonical="$1"
  local tmp digest
  tmp="$(mktemp)"
  ledger_require_python
  python3 - "$canonical" "$tmp" <<'PY'
import sys
from pathlib import Path
source = Path(sys.argv[1])
output = Path(sys.argv[2])
data = source.read_bytes()
with output.open('wb') as fh:
    fh.write(bytes.fromhex("00"))
    fh.write(data)
PY
  digest="$(ledger_hash_file "$tmp")"
  rm -f "$tmp"
  echo "$digest"
}

ledger_leaf_hash() {
  local file="$1"
  local canonical digest
  canonical="$(mktemp)"
  ledger_canonicalize_json "$file" "$canonical"
  digest="$(ledger_leaf_hash_from_canonical "$canonical")"
  rm -f "$canonical"
  echo "$digest"
}

ledger_hash_pair() {
  local left="$1" right="$2" tmp digest
  tmp="$(mktemp)"
  ledger_require_python
  python3 - "$left" "$right" "$tmp" <<'PY'
import binascii
import sys
from pathlib import Path
left, right, path = sys.argv[1], sys.argv[2], Path(sys.argv[3])
with path.open('wb') as fh:
    fh.write(bytes.fromhex("01"))
    fh.write(binascii.unhexlify(left))
    fh.write(binascii.unhexlify(right))
PY
  digest="$(ledger_hash_file "$tmp")"
  rm -f "$tmp"
  echo "$digest"
}

ledger_merkle_root() {
  # Args: list of leaf hashes (already hex strings) → echo root hash
  local -a level=("$@") next=()
  ((${#level[@]})) || { echo ""; return; }
  while ((${#level[@]} > 1)); do
    next=()
    local size=${#level[@]}
    for ((i=0; i<size; i+=2)); do
      local left="${level[i]}"
      local right="${level[i+1]:-${level[i]}}"
      next+=("$(ledger_hash_pair "$left" "$right")")
    done
    level=("${next[@]}")
  done
  echo "${level[0]}"
}

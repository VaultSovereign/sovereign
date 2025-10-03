#!/usr/bin/env bash
set -euo pipefail
# Verify daily Merkle roots produced by ledger-compact.
# Recomputes roots from raw receipts and compares against stored daily JSON.
#
# Env:
#   RECEIPTS_DIR  (default: workstation/receipts)
#   DAILY_DIR     (default: $RECEIPTS_DIR/daily)
#   DAY           (optional: YYYYMMDD; if unset, verify all days found)
#   STRICT        (default: false) → when true, fail if any day's raw receipts are missing vs recorded file list

RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
DAILY_DIR="${DAILY_DIR:-$RECEIPTS_DIR/daily}"
DAY="${DAY:-}"
STRICT="${STRICT:-false}"

mkdir -p "$RECEIPTS_DIR" "$DAILY_DIR"

have_b3sum() { command -v b3sum >/dev/null 2>&1; }
hash_file() { # prints hex digest
  if have_b3sum; then b3sum -l 256 "$1" | awk '{print $1}'; else openssl sha256 "$1" | awk '{print $2}'; fi
}
hash_pair() { # combine two hex digests deterministically
  local a="$1" b="$2" tmp; tmp="$(mktemp)"; printf "%s%s" "$a" "$b" | xxd -r -p >"$tmp"
  if have_b3sum; then b3sum -l 256 "$tmp" | awk '{print $1}'; else openssl sha256 "$tmp" | awk '{print $2}'; fi
  rm -f "$tmp"
}
merkle() { # args: list of hex digests → echo root
  local -a level=("$@") next=()
  ((${#level[@]})) || { echo ""; return; }
  while ((${#level[@]} > 1)); do
    next=()
    for ((i=0;i<${#level[@]};i+=2)); do
      a="${level[i]}"; b="${level[i+1]:-${level[i]}}"
      next+=("$(hash_pair "$a" "$b")")
    done
    level=("${next[@]}")
  done
  echo "${level[0]}"
}

say() { printf "%b %s\n" "$1" "$2"; }

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
  stored_root="$(jq -r '.root' "$meta")"
  algo="$(jq -r '.algo' "$meta")"
  # Prefer files recorded in meta.files (order-insensitive)
  mapfile -t listed < <(jq -r '.files[]' "$meta")
  actual_files=()
  # Include any remaining raw receipts matching day even if not listed (defensive)
  pattern="*-${d}T*Z.json"
  while IFS= read -r f; do actual_files+=("$(basename "$f")"); done < <(find "$RECEIPTS_DIR" -maxdepth 1 -type f -name "$pattern" | sort -r)

  # Merge unique (listed first, then any missing-but-present)
  declare -A seen=()
  merged=()
  for f in "${listed[@]}"; do
    if [[ -f "$RECEIPTS_DIR/$f" ]]; then
      seen["$f"]=1; merged+=("$f")
    else
      if [[ "$STRICT" == "true" ]]; then
        say "✖" "[$d] listed file missing: $f"; fails=$((fails+1))
      else
        say "⚠" "[$d] listed file missing (ignored in non-STRICT mode): $f"
      fi
    fi
  done
  for f in "${actual_files[@]}"; do
    [[ -n "${seen[$f]:-}" ]] || merged+=("$f")
  done

  # Hash & root
  digests=()
  for f in "${merged[@]}"; do digests+=("$(hash_file "$RECEIPTS_DIR/$f")"); done
  recomputed="$(merkle "${digests[@]}")"

  if [[ "$recomputed" == "$stored_root" ]]; then
    say "✔" "[$d] OK — root matches ($algo): $recomputed"
  else
    say "✖" "[$d] MISMATCH — stored: $stored_root  recomputed: $recomputed"
    fails=$((fails+1))
  fi
done

exit $(( fails > 0 ? 1 : 0 ))

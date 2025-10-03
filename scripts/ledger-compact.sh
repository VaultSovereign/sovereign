#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
VALIDATOR="$ROOT_DIR/scripts/receipt-validate.sh"
# Compact workstation/receipts into daily Merkle roots and prune old shards.
# Env:
#   RECEIPTS_DIR (default: workstation/receipts)
#   DAILY_DIR    (default: workstation/receipts/daily)
#   KEEP         (default: 5)     # keep latest N raw receipts per day
#   DRY_RUN      (default: false) # when true, print plan but do not write or delete
#   VERBOSE      (default: false) # when true, prints per-day file lists and actions

RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
DAILY_DIR="${DAILY_DIR:-$RECEIPTS_DIR/daily}"
KEEP="${KEEP:-5}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
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

# Group by UTC date based on timestamp in filename: *-YYYYMMDDTHHMMSSZ.json
# Portable: avoid GNU find -printf (BSD/macOS lacks it)
mapfile -t files < <(find "$RECEIPTS_DIR" -maxdepth 1 -type f -name '*.json' -exec basename {} \; | sort -r)
declare -A byday
for f in "${files[@]}"; do
  day="${f#*-}"; day="${day:0:8}"   # YYYYMMDD
  [[ "$day" =~ ^[0-9]{8}$ ]] || continue
  byday["$day"]+="$f"$'\n'
done

for day in "${!byday[@]}"; do
  # collect and hash
  IFS=$'\n' read -r -d '' -a dayfiles < <(printf "%s" "${byday[$day]}" && printf '\0')
  ((${#dayfiles[@]})) || continue
  keepN=$KEEP
  kept=( "${dayfiles[@]:0:$keepN}" )
  prune=( "${dayfiles[@]:$keepN}" )

  # hash only kept files (post-prune set)
  digests=()
  for f in "${kept[@]}"; do digests+=("$(hash_file "$RECEIPTS_DIR/$f")"); done
  root="$(merkle "${digests[@]}")"
  out="$DAILY_DIR/$day.json"

  if [[ "$VERBOSE" == "true" || "$DRY_RUN" == "true" ]]; then
    echo "— Day ${day}"
    echo "   keep:  ${#kept[@]} file(s)"
    for f in "${kept[@]}"; do echo "     ✓ $f"; done
    echo "   prune: ${#prune[@]} file(s)"
    for f in "${prune[@]}"; do echo "     ✗ $f"; done
    echo "   root:  $root"
    [[ "$DRY_RUN" == "true" ]] && echo "   plan only (no writes/deletes)"
  fi

  # write daily root (unless dry-run)
  if [[ "$DRY_RUN" != "true" ]]; then
    jq -n --arg kind "workstation.daily" \
          --arg day "$day" \
          --arg algo "$(have_b3sum && echo BLAKE3-256 || echo SHA256)" \
          --arg root "$root" \
          --argjson count "${#kept[@]}" \
          --argjson keep "$KEEP" \
          --argjson files "$(printf '%s\n' "${kept[@]}" | jq -R . | jq -s .)" \
          '{kind:$kind, day:$day, algo:$algo, root:$root, count:$count, keep:$keep, files:$files}' \
          > "$out.tmp"
    if "$VALIDATOR" "$out.tmp"; then
      mv "$out.tmp" "$out"
      echo "Daily root $day → $root ($out)"
    else
      echo "✖ invalid daily root, not written"
      rm -f "$out.tmp"
      exit 2
    fi
  fi

  # prune extras (unless dry-run)
  if [[ "$DRY_RUN" != "true" && ${#prune[@]} -gt 0 ]]; then
    for f in "${prune[@]}"; do rm -f "$RECEIPTS_DIR/$f" || true; done
    echo "Pruned ${#prune[@]} receipts for $day (kept $KEEP)."
  fi
done

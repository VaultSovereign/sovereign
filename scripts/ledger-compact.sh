#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SCRIPT_DIR
readonly ROOT_DIR
cd "$ROOT_DIR"

source "$SCRIPT_DIR/lib/ledger.sh"
# Compact workstation/receipts into daily Merkle roots and prune old shards.
# Env:
#   RECEIPTS_DIR (default: workstation/receipts)
#   DAILY_DIR    (default: workstation/receipts/daily)
#   PROOFS_DIR   (default: $DAILY_DIR/proofs)
#   KEEP         (default: 5)     # keep latest N raw receipts per day
#   DRY_RUN      (default: false) # when true, print plan but do not write or delete
#   VERBOSE      (default: false) # when true, prints per-day file lists and actions
#   FORCE        (default: false) # when false, refuse to prune if proofs cannot be written

RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
DAILY_DIR="${DAILY_DIR:-$RECEIPTS_DIR/daily}"
PROOFS_DIR="${PROOFS_DIR:-$DAILY_DIR/proofs}"
KEEP="${KEEP:-5}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
FORCE="${FORCE:-false}"

mkdir -p "$RECEIPTS_DIR" "$DAILY_DIR" "$PROOFS_DIR"

if [[ "$KEEP" -lt 0 ]]; then
  echo "✖ KEEP must be non-negative" >&2
  exit 1
fi

build_tree_levels() {
  local -n leaves_ref=$1
  local -n levels_ref=$2
  levels_ref=()
  local -a current=("${leaves_ref[@]}")
  while true; do
    levels_ref+=("${current[*]}")
    ((${#current[@]} == 1)) && break
    local -a next=()
    local size=${#current[@]}
    for ((i=0; i<size; i+=2)); do
      local left="${current[i]}"
      local right="${current[i+1]:-${current[i]}}"
      next+=("$(ledger_hash_pair "$left" "$right")")
    done
    current=("${next[@]}")
  done
}

compute_proof_path() {
  local index="$1"
  local -n levels_ref=$2
  local -a path=()
  local current_index="$index"
  local total=${#levels_ref[@]}
  for ((level=0; level<total-1; level++)); do
    read -ra nodes <<< "${levels_ref[$level]}"
    local sibling_index=$(( current_index ^ 1 ))
    local sibling_hash
    if (( sibling_index >= ${#nodes[@]} )); then
      sibling_hash="${nodes[current_index]}"
    else
      sibling_hash="${nodes[sibling_index]}"
    fi
    if (( current_index % 2 == 0 )); then
      path+=("{\"dir\":\"right\",\"hash\":\"$sibling_hash\"}")
    else
      path+=("{\"dir\":\"left\",\"hash\":\"$sibling_hash\"}")
    fi
    current_index=$(( current_index / 2 ))
  done
  if ((${#path[@]})); then
    printf '[%s]\n' "$(IFS=','; echo "${path[*]}")"
  else
    printf '[]\n'
  fi
}

# Group by UTC date based on timestamp in filename: *-YYYYMMDDTHHMMSSZ.json
# Portable: avoid GNU find -printf (BSD/macOS lacks it)
mapfile -t files < <(find "$RECEIPTS_DIR" -maxdepth 1 -type f -name '*.json' -exec basename {} \; | sort -r)
declare -A byday=()
for f in "${files[@]}"; do
  day="${f#*-}"; day="${day:0:8}"   # YYYYMMDD
  [[ "$day" =~ ^[0-9]{8}$ ]] || continue
  byday["$day"]+="$f"$'\n'
done

for day in "${!byday[@]}"; do
  IFS=$'\n' read -r -d '' -a dayfiles < <(printf "%s" "${byday[$day]}" && printf '\0')
  ((${#dayfiles[@]})) || continue

  keepN=$KEEP
  kept=("${dayfiles[@]:0:$keepN}")
  prune=("${dayfiles[@]:$keepN}")

  declare -A canonical_map=()
  declare -A leaf_map=()
  declare -A status_map=()

  for f in "${dayfiles[@]}"; do
    tmp_can="$(mktemp)"
    ledger_canonicalize_json "$RECEIPTS_DIR/$f" "$tmp_can"
    canonical_map["$f"]="$tmp_can"
    leaf_map["$f"]="$(ledger_leaf_hash_from_canonical "$tmp_can")"
    status_map["$f"]="pruned"
  done
  for f in "${kept[@]}"; do status_map["$f"]="kept"; done

  entries=()
  for f in "${dayfiles[@]}"; do
    entries+=("${leaf_map[$f]}|${status_map[$f]}|$f")
  done

  sorted_entries=()
  if ((${#entries[@]})); then
    mapfile -t sorted_entries < <(printf '%s\n' "${entries[@]}" | sort)
  fi

  sorted_hashes=()
  sorted_records=()
  declare -A index_map=()
  idx=0
  for entry in "${sorted_entries[@]}"; do
    IFS='|' read -r hash status file <<<"$entry"
    sorted_hashes+=("$hash")
    proof_path=""
    if [[ "$status" == "pruned" ]]; then
      proof_path="proofs/$day/${hash}.json"
    fi
    sorted_records+=("$idx|$hash|$file|$status|$proof_path")
    index_map["$file"]="$idx"
    ((idx++))
  done

  if ((${#sorted_hashes[@]} == 0)); then
    for f in "${dayfiles[@]}"; do rm -f "${canonical_map[$f]}" 2>/dev/null || true; done
    continue
  fi

  hash_algo="$(ledger_hash_algo_name)"
  root="$(ledger_merkle_root "${sorted_hashes[@]}")"
  inputs_digest="$(printf '%s\n' "${sorted_hashes[@]}" | ledger_hex_concat_hash)"
  iso_day="${day:0:4}-${day:4:2}-${day:6:2}"
  ts="$(date -u +%Y%m%dT%H%M%SZ)"

  files_json="[]"
  if ((${#sorted_records[@]})); then
    files_json="$(printf '%s\n' "${sorted_records[@]}" | jq -R 'split("|") | {index:(.[0]|tonumber), leaf_hash: .[1], file: .[2], retained:(.[3]=="kept")} + (.[4]==""?{}:{proof: .[4]})' | jq -s '.')"
  fi

  if [[ "$VERBOSE" == "true" || "$DRY_RUN" == "true" ]]; then
    echo "— Day ${day} (UTC)"
    echo "   keep:   ${#kept[@]} file(s)"
    for f in "${kept[@]}"; do echo "     ✓ $f"; done
    echo "   prune:  ${#prune[@]} file(s)"
    for f in "${prune[@]}"; do echo "     ✗ $f"; done
    echo "   leaves: ${#sorted_hashes[@]}"
    echo "   root:   $root"
    [[ "$DRY_RUN" == "true" ]] && echo "   plan only (no writes/deletes)"
  fi

  out="$DAILY_DIR/$day.json"
  if [[ "$DRY_RUN" != "true" ]]; then
    jq -n --arg kind "workstation.daily" \
          --arg schema_version "1.1" \
          --arg ts "$ts" \
          --arg timezone "UTC" \
          --arg day "$day" \
          --arg date_utc "$iso_day" \
          --arg hash_algo "$hash_algo" \
          --arg canonicalization "$LEDGER_CANONICALIZATION" \
          --arg order "asc-leaf-hash" \
          --arg root "$root" \
          --arg inputs_digest "$inputs_digest" \
          --arg domain_version "$LEDGER_DOMAIN_VERSION" \
          --argjson leaf_count "${#sorted_hashes[@]}" \
          --argjson count "${#kept[@]}" \
          --argjson keep "$KEEP" \
          --argjson pruned_count "${#prune[@]}" \
          --argjson domain '{"leaf":"00","node":"01"}' \
          --argjson files "$files_json" \
          '{kind:$kind, schema_version:$schema_version, ts:$ts, timezone:$timezone, day:$day, date_utc:$date_utc, hash_algo:$hash_algo, canonicalization:$canonicalization, domain_separation:$domain, domain_version:$domain_version, order:$order, root:$root, inputs_digest:$inputs_digest, leaf_count:$leaf_count, count:$count, keep:$keep, pruned_count:$pruned_count, files:$files}' \
          > "$out.tmp"
    # Single authoritative validation path (no wrapper). Only promote to the
    # canonical location on success to preserve the previous state on failure.
    if "$ROOT_DIR/scripts/receipt-validate.sh" "$out.tmp"; then
      mv "$out.tmp" "$out"
      echo "Daily root $day → $root ($out)"
    else
      echo "✖ invalid daily root, not written"
      rm -f "$out.tmp"
      exit 2
    fi
  fi

  declare -a tree_levels=()
  build_tree_levels sorted_hashes tree_levels

  proofs_ok=true
  if [[ "$DRY_RUN" != "true" && ${#prune[@]} -gt 0 ]]; then
    if ! command -v base64 >/dev/null 2>&1; then
      if [[ "$FORCE" == "true" ]]; then
        echo "⚠ skipping proof emission for $day (base64 unavailable, FORCE=true)" >&2
        proofs_ok=false
      else
        echo "✖ base64 is required to emit proofs" >&2
        exit 1
      fi
    fi
    if [[ "$proofs_ok" == "true" ]]; then
      mkdir -p "$PROOFS_DIR/$day"
      for f in "${prune[@]}"; do
        idx_for_file="${index_map[$f]}"
        leaf_hash="${leaf_map[$f]}"
        canonical_path="${canonical_map[$f]}"
        proof_json="$(compute_proof_path "$idx_for_file" tree_levels)"
        canon_b64="$(base64 <"$canonical_path" | tr -d '\n')"
        canon_len="$(wc -c <"$canonical_path" | tr -d '[:space:]')"
        receipt_hash="$(ledger_hash_file "$canonical_path")"
        proof_ts="$(date -u +%Y%m%dT%H%M%SZ)"
        proof_out="$PROOFS_DIR/$day/${leaf_hash}.json"
        jq -n --arg kind "workstation.proof" \
              --arg schema_version "1.1" \
              --arg timezone "UTC" \
              --arg day "$day" \
              --arg date_utc "$iso_day" \
              --arg file "$f" \
              --arg leaf_hash "$leaf_hash" \
              --arg root "$root" \
              --arg hash_algo "$hash_algo" \
              --arg canonicalization "$LEDGER_CANONICALIZATION" \
              --arg order "asc-leaf-hash" \
              --arg domain_version "$LEDGER_DOMAIN_VERSION" \
              --arg root_ts "$ts" \
              --arg proof_ts "$proof_ts" \
              --arg receipt_b64 "$canon_b64" \
              --argjson receipt_len "$canon_len" \
              --arg receipt_hash "$receipt_hash" \
              --argjson leaf_index "$idx_for_file" \
              --argjson domain '{"leaf":"00","node":"01"}' \
              --argjson path "$proof_json" \
              '{kind:$kind, schema_version:$schema_version, timezone:$timezone, day:$day, date_utc:$date_utc, file:$file, leaf_hash:$leaf_hash, leaf_index:$leaf_index, root:$root, hash_algo:$hash_algo, canonicalization:$canonicalization, domain_separation:$domain, domain_version:$domain_version, order:$order, root_ts:$root_ts, proof_ts:$proof_ts, receipt_len:$receipt_len, receipt_hash:$receipt_hash, path:$path, receipt_b64:$receipt_b64}' \
              > "$proof_out.tmp"
        mv "$proof_out.tmp" "$proof_out"
      done
    fi
  fi

  if [[ "$DRY_RUN" != "true" && ${#prune[@]} -gt 0 ]]; then
    if [[ "$proofs_ok" == "true" || "$FORCE" == "true" ]]; then
      for f in "${prune[@]}"; do
        rm -f "$RECEIPTS_DIR/$f" || true
      done
      echo "Pruned ${#prune[@]} receipts for $day (kept $KEEP, proofs in $PROOFS_DIR/$day)."
    else
      echo "✖ proofs missing; refusing to prune receipts for $day" >&2
      exit 1
    fi
  fi

  for f in "${dayfiles[@]}"; do
    rm -f "${canonical_map[$f]}" 2>/dev/null || true
  done
done

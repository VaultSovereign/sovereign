#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"
VALIDATOR="$ROOT_DIR/scripts/receipt-validate.sh"
# Bulk heuristic fixer. Runs scripts/find-fix-bug.sh on many files and prints a summary.
#
# Usage:
#   scripts/find-fix-all.sh [--dry-run] [--jobs N] [--include "<glob1> <glob2>"] [--exclude "<glob1> <glob2>"]
# Env:
#   NON_VENDOR_ONLY=true|false (default true)  # skip node_modules/vendor/dist/build
#   SEARCH_ROOT (default .)                    # base for non-git search
#   DRY_RUN=true|false                         # alias for --dry-run
#   JOBS (default: CPU count or 4)             # alias for --jobs
#
# Exit codes: 0 OK (no errors), 1 some files failed to process, 2 usage error

NON_VENDOR_ONLY="${NON_VENDOR_ONLY:-true}"
SEARCH_ROOT="${SEARCH_ROOT:-.}"
DRY="${DRY_RUN:-false}"
JOBS_DEFAULT="$( (getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4) )"
JOBS="${JOBS:-$JOBS_DEFAULT}"

INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY="true"; shift ;;
    --jobs) JOBS="${2:-}"; shift 2 ;;
    --include) IFS=' ' read -r -a INCLUDE_PATTERNS <<< "${2:-}"; shift 2 ;;
    --exclude) IFS=' ' read -r -a EXCLUDE_PATTERNS <<< "${2:-}"; shift 2 ;;
    *) echo "usage: $0 [--dry-run] [--jobs N] [--include \"<globs>\"] [--exclude \"<globs>\"]"; exit 2 ;;
  esac
done

# Candidate set (tracked files if git repo; else portable find)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  mapfile -t CANDIDATES < <(git ls-files)
else
  mapfile -t CANDIDATES < <(find "$SEARCH_ROOT" -type f 2>/dev/null | sed 's#^\./##')
fi

# Vendor filter
filtered=()
for p in "${CANDIDATES[@]}"; do
  if [[ "$NON_VENDOR_ONLY" == "true" ]] && [[ "$p" =~ (^|/)(node_modules|vendor|dist|build)(/|$) ]]; then
    continue
  fi
  filtered+=("$p")
done
CANDIDATES=("${filtered[@]}")

# Glob helpers
matches_any() {
  local f="$1"; shift
  local arr=("$@")
  ((${#arr[@]}==0)) && return 0
  for g in "${arr[@]}"; do [[ "$f" == $g ]] && return 0; done
  return 1
}
matches_none() {
  local f="$1"; shift
  local arr=("$@")
  for g in "${arr[@]}"; do [[ "$f" == $g ]] && return 1; done
  return 0
}

# Apply include/exclude
picked=()
for p in "${CANDIDATES[@]}"; do
  matches_any "$p" "${INCLUDE_PATTERNS[@]}" || continue
  matches_none "$p" "${EXCLUDE_PATTERNS[@]}" || continue
  picked+=("$p")
done

# If no includes specified, default to common code/doc types
if ((${#INCLUDE_PATTERNS[@]}==0)); then
  picked=()
  for p in "${CANDIDATES[@]}"; do
    case "$p" in
      *.sh|*.bash|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.json|*.yaml|*.yml|*.md|*.rs) picked+=("$p") ;;
    esac
  done
fi

# DRY banner
if [[ "$DRY" == "true" ]]; then
  echo "DRY-RUN: would process ${#picked[@]} file(s) with jobs=$JOBS"
fi

# Work queue (basic xargs -P parallelism)
tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
summary="$tmpdir/summary.tsv"; : >"$summary"
errs=0

# Receipt controls
RECEIPT="${RECEIPT:-false}"
RECEIPTS_DIR="${RECEIPTS_DIR:-workstation/receipts}"
RECEIPT_PREFIX="${RECEIPT_PREFIX:-fixall}"
MODE="$([[ "$DRY" == "true" ]] && echo "dry-run" || echo "apply")"

process_one() {
  local f="$1" dry="$2" out="$3"
  # Always snapshot original
  local before after diff_lines changed
  before="$(mktemp)"; after="$(mktemp)"
  cp "$f" "$before"

  # Delegate to single-file tool (it edits in place)
  bash scripts/find-fix-bug.sh "$f" >/dev/null || true
  cp "$f" "$after"

  # Compute diff and change flag
  diff_lines="$(diff -u "$before" "$after" | wc -l | tr -d ' ')"
  changed="no"; (( diff_lines > 0 )) && changed="yes"

  # True dry-run: restore original bytes
  if [[ "$dry" == "true" ]]; then
    cp "$before" "$f"
  fi

  printf "%s\t%s\t%s\n" "$f" "$changed" "$diff_lines" >> "$out"
  rm -f "$before" "$after"
}

export -f process_one
export NON_VENDOR_ONLY SEARCH_ROOT

# Feed paths to xargs with jobs
printf "%s\0" "${picked[@]}" | xargs -0 -n1 -P "${JOBS}" bash -c 'process_one "$0" "'"$DRY"'" "'"$summary"'"' 

# Summarize
total=${#picked[@]}
changed_count=$(awk -F'\t' '$2=="yes"{c++} END{print c+0}' "$summary")
diff_total=$(awk -F'\t' '{s+=$3} END{print s+0}' "$summary")

echo
echo "=== FIX-ALL SUMMARY ==="
printf "files_scanned\t%d\n" "$total"
printf "files_changed\t%d\n" "$changed_count"
printf "diff_lines\t%d\n" "$diff_total"
echo
# Pretty table (top 20 changed)
echo "Top changed files:"
awk -F'\t' 'BEGIN{printf("%-6s  %-5s  %s\n","lines","chg?","file")} {printf("%-6s  %-5s  %s\n",$3,$2,$1)}' "$summary" \
  | sort -k1,1nr | sed -n '1,21p'

# Emit receipt
if [[ "$RECEIPT" == "true" ]]; then
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$RECEIPTS_DIR"
  out="${RECEIPTS_DIR}/${RECEIPT_PREFIX}-${ts}.json"
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg kind "fixall.run" \
      --arg ts "$ts" \
      --arg mode "$MODE" \
      --arg dry_run "$DRY" \
      --arg non_vendor_only "$NON_VENDOR_ONLY" \
      --arg search_root "$SEARCH_ROOT" \
      --arg include_globs "${INCLUDE_PATTERNS[*]:-}" \
      --arg exclude_globs "${EXCLUDE_PATTERNS[*]:-}" \
      --arg jobs "$JOBS" \
      --argjson files_scanned "$total" \
      --argjson files_changed "$changed_count" \
      --argjson diff_lines "$diff_total" \
      --rawfile tsv "$summary" \
      'def parse_tsv($s):
         ($s
          | split("\n")
          | map(select(length>0)
                | (split("\t") as $r
                  | {file: $r[0],
                     changed: ($r[1]=="yes"),
                     diff_lines: ($r[2]|tonumber)})));
       {
         kind:$kind, ts:$ts, mode:$mode,
         params:{
           dry_run:($dry_run=="true"),
           non_vendor_only:($non_vendor_only=="true"),
           search_root:$search_root,
           include: ([$include_globs] | map(select(length>0)) | (.[0] // "") | split(" ") | map(select(length>0))),
           exclude: ([$exclude_globs] | map(select(length>0)) | (.[0] // "") | split(" ") | map(select(length>0))),
           jobs: ($jobs|tonumber?)
         },
         stats:{files_scanned:$files_scanned, files_changed:$files_changed, diff_lines:$diff_lines},
         files: parse_tsv($tsv)
       }' > "$out.tmp"
    if scripts/receipt-validate.sh "$out.tmp"; then
      mv "$out.tmp" "$out"
      echo "Fix-all receipt: $out"
    else
      echo "✖ invalid receipt, not written"
      rm -f "$out.tmp"
      exit 2
    fi
  else
    echo "⚠ jq not found; skipping receipt." >&2
  fi
fi

# Exit non-zero if any processing failed (tolerant by default)
exit "$errs"

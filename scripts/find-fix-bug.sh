#!/usr/bin/env bash
set -euo pipefail
# Usage:
#   scripts/find-fix-bug.sh [--list|--choose] <@filename|path>
# Flags:
#   --list    : list candidate matches and exit (no changes)
#   --choose  : interactively choose a match (fzf if present, else numeric prompt)
# Env:
#   NON_VENDOR_ONLY=true|false (default true) → prefer non-vendored paths
#   SEARCH_ROOT (default .) → base for non-git search
#   CHOOSE_DEFAULT (number) → preselect index in non-interactive environments
#
# Heuristic fixer that runs language-appropriate linters/formatters and prints a focused diff.

NON_VENDOR_ONLY="${NON_VENDOR_ONLY:-true}"
SEARCH_ROOT="${SEARCH_ROOT:-.}"
CHOOSE_DEFAULT="${CHOOSE_DEFAULT:-}"

mode="default"
if [[ "${1:-}" == "--list" ]]; then mode="list"; shift; fi
if [[ "${1:-}" == "--choose" ]]; then mode="choose"; shift; fi

arg="${1:-}"; [[ -n "$arg" ]] || { echo "usage: $0 [--list|--choose] <@filename|path>"; exit 2; }

# Resolve @filename to a ranked candidate list
resolve_at() {
  local name="$1"
  name="${name#@}"
  local -a all=()
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mapfile -t all < <(git ls-files)
  else
    mapfile -t all < <(find "$SEARCH_ROOT" -type f 2>/dev/null | sed 's#^\./##')
  fi
  local -a matches_exact=() matches_sub_base=() matches_sub_path=()
  for p in "${all[@]}"; do
    base="${p##*/}"
    if [[ "$base" == "$name" ]]; then matches_exact+=("$p"); continue; fi
    if [[ "$base" == *"$name"* ]]; then matches_sub_base+=("$p"); continue; fi
    if [[ "$p" == *"$name"* ]]; then matches_sub_path+=("$p"); fi
  done
  pick_from() {
    local -n arr="$1"
    if [[ "${NON_VENDOR_ONLY}" == "true" ]]; then
      for x in "${arr[@]}"; do [[ "$x" =~ (^|/)(node_modules|vendor|dist|build)(/|$) ]] && continue; echo "$x"; done
    else
      printf '%s\n' "${arr[@]}"
    fi
  }
  mapfile -t ranked < <(pick_from matches_exact; pick_from matches_sub_base; pick_from matches_sub_path)
  printf '%s\n' "${ranked[@]}"
}

choose_one() {
  mapfile -t opts < <(printf '%s\n' "$@")
  ((${#opts[@]})) || return 1
  if [[ "$mode" == "list" ]]; then printf '%s\n' "${opts[@]}"; return 0; fi
  if [[ "$mode" == "choose" ]]; then
    if command -v fzf >/dev/null 2>&1; then
      fzf --prompt="Select file > " --height=20 --layout=reverse <<<"$(printf "%s\n" "${opts[@]}")"
      return $?
    else
      if [[ -t 0 && -t 1 ]]; then
        local i=1
        for o in "${opts[@]}"; do printf "%2d) %s\n" "$i" "$o"; ((i++)); done
        read -r -p "Choose [1-${#opts[@]}]: " n
        [[ "$n" =~ ^[0-9]+$ ]] && ((n>=1 && n<=${#opts[@]})) || return 2
        echo "${opts[$((n-1))]}"; return 0
      fi
      if [[ -n "$CHOOSE_DEFAULT" ]] && (( CHOOSE_DEFAULT>=1 && CHOOSE_DEFAULT<=${#opts[@]} )); then
        echo "${opts[$((CHOOSE_DEFAULT-1))]}"; return 0
      fi
      echo "${opts[0]}"; return 0
    fi
  fi
  echo "${opts[0]}"
}

if [[ "$arg" == @* ]]; then
  mapfile -t candidates < <(resolve_at "$arg" || true)
  ((${#candidates[@]})) || { echo "could not resolve $arg in repo"; exit 2; }
  if [[ "$mode" == "list" ]]; then printf '%s\n' "${candidates[@]}"; exit 0; fi
  file="$(choose_one "${candidates[@]}")" || { echo "no selection made"; exit 2; }
else
  file="$arg"
fi

[[ -f "$file" ]] || { echo "no such file: $file" >&2; exit 2; }

ext="${file##*.}"
before="$(mktemp)"; after="$(mktemp)"
cp "$file" "$before"

run() { echo "→ $*"; "$@"; }

case "$ext" in
  sh|bash)
    command -v shellcheck >/dev/null 2>&1 && run shellcheck -x "$file" || true
    command -v shfmt >/dev/null 2>&1 && run shfmt -w "$file" || true
    ;;
  js|mjs|cjs|ts|tsx)
    if command -v pnpm >/dev/null 2>&1 && pnpm -v >/dev/null 2>&1; then
      (pnpm -w exec eslint --version >/dev/null 2>&1) && run pnpm -w exec eslint --fix "$file" || true
      (pnpm -w exec prettier --version >/dev/null 2>&1) && run pnpm -w exec prettier --write "$file" || true
      (pnpm -w exec tsc --version >/dev/null 2>&1) && run pnpm -w exec tsc -p . --noEmit || true
    fi
    ;;
  json)
    if command -v jq >/dev/null 2>&1; then
      run jq . "$file" >"$after" && mv "$after" "$file"
    fi
    ;;
  yml|yaml)
    command -v yq >/dev/null 2>&1 && run yq -e '.' "$file" >/dev/null || true
    ;;
  md)
    command -v prettier >/dev/null 2>&1 && run prettier --write "$file" || true
    ;;
  rs)
    command -v cargo >/dev/null 2>&1 && run cargo fmt -- "$file" || true
    ;;
  *)
    echo "No fixer for *.$ext; showing context-only diff."
    ;;
esac

cp "$file" "$after"
echo
echo "=== DIFF ($file) ==="
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git --no-pager diff --no-index -- "$before" "$after" || true
else
  diff -u "$before" "$after" || true
fi

# Simple success heuristic: file changed or linters produced no errors
if cmp -s "$before" "$after"; then
  echo "No changes applied. Inspect linter output above for hints."
else
  echo "Applied fixes to $file."
fi

rm -f "$before" "$after"

#!/usr/bin/env bash
# Resolves which package manager, cache mode and lockfile apply to WORKDIR.
#
# Runs before Node is set up, so it only uses POSIX tools (no node, no jq).
# Compatible with bash 3.2 (macOS) and Git Bash (Windows).
#
# Inputs (environment):
#   WORKDIR      working directory, relative to the workspace (default ".")
#   PM_INPUT     auto | npm | yarn | pnpm | bun (default "auto")
#   CACHE_INPUT  "" | auto | npm | yarn | pnpm (default "")
#
# Outputs (appended to $GITHUB_OUTPUT):
#   name                   resolved package manager
#   corepack               "true" when corepack must be enabled (yarn, pnpm)
#   lockfile               lockfile path relative to the workspace, or ""
#   cache                  value for the setup-node `cache` input, or ""
#   cache-dependency-path  value for the setup-node `cache-dependency-path` input, or ""
#
# Resolution order for "auto":
#   1. the `packageManager` field of the nearest package.json that has one
#   2. the nearest directory (working directory, then its parents inside the
#      workspace) that holds a lockfile: pnpm > yarn > bun > npm
#   3. npm
set -euo pipefail

WORKDIR=${WORKDIR:-.}
PM_INPUT=${PM_INPUT:-auto}
CACHE_INPUT=${CACHE_INPUT:-}
OUT=${GITHUB_OUTPUT:-/dev/stdout}

lock_names() {
  case "$1" in
    npm) echo "package-lock.json npm-shrinkwrap.json" ;;
    yarn) echo "yarn.lock" ;;
    pnpm) echo "pnpm-lock.yaml" ;;
    bun) echo "bun.lock bun.lockb" ;;
    *) echo "" ;;
  esac
}

is_supported() {
  case "$1" in
    npm | yarn | pnpm | bun) return 0 ;;
    *) return 1 ;;
  esac
}

# Directories to inspect: WORKDIR first, then each parent up to the workspace
# root. Parents are only walked for plain relative paths (no "..", not absolute).
dirs=()
d=${WORKDIR%/}
d=${d#./}
[ -n "$d" ] || d=.
dirs+=("$d")
case "$d" in
  . | /* | ..* | */../* | */..) ;;
  *)
    while [ "$d" != "." ]; do
      case "$d" in
        */*) d=${d%/*} ;;
        *) d=. ;;
      esac
      dirs+=("$d")
    done
    ;;
esac

# Prints the path of the first lockfile for $1 found in dirs; fails if none.
find_lock() {
  local dir name
  for dir in "${dirs[@]}"; do
    # shellcheck disable=SC2046 # lock_names prints a space-separated list on purpose
    for name in $(lock_names "$1"); do
      if [ -f "$dir/$name" ]; then
        if [ "$dir" = "." ]; then echo "$name"; else echo "$dir/$name"; fi
        return 0
      fi
    done
  done
  return 1
}

field_pm=""
for dir in "${dirs[@]}"; do
  if [ -f "$dir/package.json" ]; then
    value=$(sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"\([A-Za-z]*\)@.*/\1/p' "$dir/package.json" | head -n 1)
    if [ -n "$value" ]; then
      field_pm=$value
      break
    fi
  fi
done

pm=""
if [ "$PM_INPUT" != "auto" ] && [ -n "$PM_INPUT" ]; then
  if ! is_supported "$PM_INPUT"; then
    echo "::error::package-manager must be one of: auto, npm, yarn, pnpm, bun (got '$PM_INPUT')"
    exit 1
  fi
  pm=$PM_INPUT
elif [ -n "$field_pm" ] && is_supported "$field_pm"; then
  pm=$field_pm
else
  if [ -n "$field_pm" ]; then
    echo "::warning::package.json packageManager '$field_pm' is not supported; falling back to lockfile detection"
  fi
  for dir in "${dirs[@]}"; do
    for candidate in pnpm yarn bun npm; do
      # shellcheck disable=SC2046 # lock_names prints a space-separated list on purpose
      for name in $(lock_names "$candidate"); do
        if [ -z "$pm" ] && [ -f "$dir/$name" ]; then
          pm=$candidate
        fi
      done
    done
    [ -z "$pm" ] || break
  done
  [ -n "$pm" ] || pm=npm
fi

lock=$(find_lock "$pm" || true)

cache=""
dep_path=""
case "$CACHE_INPUT" in
  "") ;;
  auto)
    case "$pm" in
      npm | yarn | pnpm) [ -z "$lock" ] || cache=$pm ;;
    esac
    ;;
  *) cache=$CACHE_INPUT ;;
esac
if [ -n "$cache" ]; then
  if [ "$cache" = "$pm" ] && [ -n "$lock" ]; then
    dep_path=$lock
  else
    # Explicit cache that does not match the package manager, or no lockfile
    # found: keep the historical glob so setup-node reports a clear error.
    first=$(lock_names "$cache" | cut -d' ' -f1)
    [ -n "$first" ] || first=package-lock.json
    base=${WORKDIR%/}
    base=${base#./}
    if [ -z "$base" ] || [ "$base" = "." ]; then
      dep_path="**/$first"
    else
      dep_path="$base/**/$first"
    fi
  fi
fi

corepack=false
case "$pm" in
  yarn | pnpm) corepack=true ;;
esac

{
  echo "name=$pm"
  echo "corepack=$corepack"
  echo "lockfile=$lock"
  echo "cache=$cache"
  echo "cache-dependency-path=$dep_path"
} >> "$OUT"

echo "package manager: $pm (lockfile: ${lock:-none}, cache: ${cache:-none})"

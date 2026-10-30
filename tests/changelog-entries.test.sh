#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$root/scripts/changelog-check.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Use a fixture instead of a real entry: release PRs consume every file in
# .changelog/, so the repo's own entries are not guaranteed to exist.
mkdir -p "$tmp/good/.changelog"
printf 'semver: minor\nAdded a fixture entry.\n' >"$tmp/good/.changelog/ok.md"
ENTRY_DIR="$tmp/good/.changelog" bash "$root/scripts/changelog-check.sh"

mkdir -p "$tmp/.changelog"
printf 'semver: banana\nBroken\n' >"$tmp/.changelog/bad.md"
if ENTRY_DIR="$tmp/.changelog" bash "$root/scripts/changelog-check.sh"; then
  echo "expected failure for bad semver" >&2
  exit 1
fi

echo "changelog-entries: ok"

#!/usr/bin/env bash
# Extract the body of one Keep a Changelog section (no heading line).
# Usage: changelog-section.sh <version> [CHANGELOG.md]
set -euo pipefail

version="${1:?version required (bare MAJOR.MINOR.PATCH)}"
changelog="${2:-CHANGELOG.md}"

if [[ ! -f "$changelog" ]]; then
  echo "changelog-section: file not found: $changelog" >&2
  exit 1
fi

if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "changelog-section: bad version '$version'" >&2
  exit 1
fi

awk -v v="$version" '
  BEGIN { gsub(/\./, "\\.", v) }
  $0 ~ "^## \\[?v?" v "\\]?" { inside = 1; next }
  inside && /^## / { exit }
  inside { print }
' "$changelog"

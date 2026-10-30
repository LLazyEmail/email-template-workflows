#!/usr/bin/env bash
# Print the newest Keep a Changelog version heading from a changelog file.
# Skips [Unreleased]. Prints bare MAJOR.MINOR.PATCH to stdout, or nothing.
set -euo pipefail

changelog="${1:-CHANGELOG.md}"

if [[ ! -f "$changelog" ]]; then
  echo "changelog-latest-version: file not found: $changelog" >&2
  exit 1
fi

# First matching ## [X.Y.Z] or ## X.Y.Z (optional v prefix inside brackets).
sed -nE 's/^##[[:space:]]+\[?v?([0-9]+\.[0-9]+\.[0-9]+)\]?.*/\1/p' "$changelog" | head -n1

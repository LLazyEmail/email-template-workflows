#!/usr/bin/env bash
# Validate .changelog/*.md entry headers (semver required; type optional).
# Exit 0 when the directory is empty or every flat *.md (except README.md) is valid.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="${ENTRY_DIR:-$root/.changelog}"

if [[ ! -d "$dir" ]]; then
  echo "changelog-check: missing directory $dir" >&2
  exit 1
fi

# Nested dirs are not allowed (same rule as actions-changelog v2).
shopt -s nullglob
nested=("$dir"/*/)
if ((${#nested[@]} > 0)); then
  echo "changelog-check: entries must be flat files in $dir; found subdirectories:" >&2
  printf '  %s\n' "${nested[@]}" >&2
  exit 1
fi

ok=0
fail=0
for f in "$dir"/*.md; do
  base="$(basename "$f")"
  if [[ "$base" == "README.md" ]]; then
    continue
  fi
  ok=1
  semver=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      'semver: '*)
        semver="${line#semver: }"
        semver="${semver#"${semver%%[![:space:]]*}"}"
        semver="${semver%"${semver##*[![:space:]]}"}"
        ;;
      'type: '*)
        ;;
      '')
        ;;
      *)
        break
        ;;
    esac
  done <"$f"

  body="$(awk '
    BEGIN { hdr=1 }
    hdr && ($0 ~ /^semver: / || $0 ~ /^type: / || $0 == "") { next }
    { hdr=0; print }
  ' "$f" | sed "/./,\$!d")"

  if [[ -z "$semver" ]]; then
    echo "changelog-check: $base: missing required 'semver: major|minor|patch' header" >&2
    fail=1
    continue
  fi
  case "$semver" in
    major|minor|patch) ;;
    *)
      echo "changelog-check: $base: invalid semver '$semver' (want major|minor|patch)" >&2
      fail=1
      continue
      ;;
  esac
  if [[ -z "$body" ]]; then
    echo "changelog-check: $base: empty body after header" >&2
    fail=1
    continue
  fi
  echo "changelog-check: $base ok (semver=$semver)"
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
if [[ "$ok" -eq 0 ]]; then
  echo "changelog-check: no entry files (only README) — ok"
fi

#!/usr/bin/env bash
# Unit tests for changelog version / section helpers used by tag-release.yml.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

latest="$root/scripts/changelog-latest-version.sh"
section="$root/scripts/changelog-section.sh"

cat >"$tmp/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

### Added

- pending

## [1.2.0] - 2026-10-01

### Added

- Feature A
- Feature B

### Fixed

- Bug Z

## [1.1.0] - 2026-09-01

### Added

- Older
MD

# Unreleased first: newest version heading must still be 1.2.0
got="$("$latest" "$tmp/CHANGELOG.md")"
[[ "$got" == "1.2.0" ]] || { echo "expected 1.2.0, got '$got'" >&2; exit 1; }

# Section body excludes the heading and stops at the next ##
"$section" 1.2.0 "$tmp/CHANGELOG.md" >"$tmp/notes.md"
grep -q 'Feature A' "$tmp/notes.md" || { echo "missing Feature A" >&2; exit 1; }
grep -q 'Bug Z' "$tmp/notes.md" || { echo "missing Bug Z" >&2; exit 1; }
if grep -q 'Older' "$tmp/notes.md"; then
  echo "section leaked into next version" >&2
  exit 1
fi
if grep -q '1.2.0' "$tmp/notes.md"; then
  echo "section should omit the heading line" >&2
  exit 1
fi

# Repo changelog must resolve to some X.Y.Z (release PRs bump it).
repo_ver="$("$latest" "$root/CHANGELOG.md")"
[[ "$repo_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "expected repo semver X.Y.Z, got '$repo_ver'" >&2
  exit 1
}

# Empty / no version
printf '# Changelog\n\n## [Unreleased]\n\n- x\n' >"$tmp/empty.md"
empty="$("$latest" "$tmp/empty.md" || true)"
[[ -z "$empty" ]] || { echo "expected empty, got '$empty'" >&2; exit 1; }

echo "tag-release: ok"

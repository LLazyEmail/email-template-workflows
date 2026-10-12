#!/usr/bin/env bash
# Tests for scripts/detect-package-manager.sh using throwaway project layouts.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# detect <workspace-relative workdir> [pm-input] [cache-input]
# Runs the script from inside TMP (the "workspace") and fills $OUT.
detect() {
  OUT="$TMP/output.txt"
  : > "$OUT"
  (
    cd "$TMP/ws"
    WORKDIR=$1 PM_INPUT=${2:-auto} CACHE_INPUT=${3:-} GITHUB_OUTPUT=$OUT \
      bash "$ROOT/scripts/detect-package-manager.sh" > /dev/null
  )
}

fresh() {
  rm -rf "$TMP/ws"
  mkdir -p "$TMP/ws"
}

echo "detect-package-manager.sh"

fresh
echo '{}' > "$TMP/ws/package.json"
detect .
assert_eq "no lockfile defaults to npm" npm "$(output_of "$OUT" name)"
assert_eq "no lockfile means corepack off" false "$(output_of "$OUT" corepack)"
assert_eq "no lockfile, cache stays empty" "" "$(output_of "$OUT" cache)"

fresh
echo '{}' > "$TMP/ws/package.json"
touch "$TMP/ws/pnpm-lock.yaml"
detect .
assert_eq "pnpm-lock.yaml selects pnpm" pnpm "$(output_of "$OUT" name)"
assert_eq "pnpm needs corepack" true "$(output_of "$OUT" corepack)"
assert_eq "lockfile path reported" pnpm-lock.yaml "$(output_of "$OUT" lockfile)"

fresh
touch "$TMP/ws/yarn.lock"
detect .
assert_eq "yarn.lock selects yarn" yarn "$(output_of "$OUT" name)"

fresh
touch "$TMP/ws/bun.lock"
detect .
assert_eq "bun.lock selects bun" bun "$(output_of "$OUT" name)"
assert_eq "bun does not need corepack" false "$(output_of "$OUT" corepack)"

fresh
touch "$TMP/ws/bun.lockb"
detect .
assert_eq "bun.lockb selects bun" bun "$(output_of "$OUT" name)"

fresh
touch "$TMP/ws/package-lock.json"
detect .
assert_eq "package-lock.json selects npm" npm "$(output_of "$OUT" name)"

fresh
touch "$TMP/ws/package-lock.json" "$TMP/ws/pnpm-lock.yaml"
detect .
assert_eq "pnpm wins over npm when both lockfiles exist" pnpm "$(output_of "$OUT" name)"

fresh
echo '{"packageManager": "yarn@4.1.0"}' > "$TMP/ws/package.json"
touch "$TMP/ws/package-lock.json"
detect .
assert_eq "packageManager field wins over lockfile" yarn "$(output_of "$OUT" name)"

fresh
printf '{\n  "name": "x",\n  "packageManager": "pnpm@9.1.0+sha512.abc"\n}\n' > "$TMP/ws/package.json"
detect .
assert_eq "packageManager with integrity hash is parsed" pnpm "$(output_of "$OUT" name)"

fresh
echo '{"packageManager": "pnpm@9.1.0"}' > "$TMP/ws/package.json"
detect . npm
assert_eq "explicit package-manager overrides detection" npm "$(output_of "$OUT" name)"

fresh
echo '{"packageManager": "deno@2.0.0"}' > "$TMP/ws/package.json"
touch "$TMP/ws/yarn.lock"
detect .
assert_eq "unsupported packageManager falls back to lockfile" yarn "$(output_of "$OUT" name)"

# Monorepo: lockfile at the workspace root, working directory is a package
fresh
mkdir -p "$TMP/ws/packages/emails"
echo '{}' > "$TMP/ws/packages/emails/package.json"
touch "$TMP/ws/pnpm-lock.yaml"
detect packages/emails
assert_eq "monorepo: parent lockfile is found" pnpm "$(output_of "$OUT" name)"
assert_eq "monorepo: lockfile path is workspace-relative" pnpm-lock.yaml "$(output_of "$OUT" lockfile)"

fresh
mkdir -p "$TMP/ws/packages/emails"
echo '{}' > "$TMP/ws/packages/emails/package.json"
echo '{"packageManager": "yarn@4.0.0"}' > "$TMP/ws/package.json"
detect packages/emails
assert_eq "monorepo: parent packageManager field is found" yarn "$(output_of "$OUT" name)"

fresh
mkdir -p "$TMP/ws/packages/emails"
touch "$TMP/ws/yarn.lock" "$TMP/ws/packages/emails/package-lock.json"
detect packages/emails
assert_eq "monorepo: nearest lockfile wins" npm "$(output_of "$OUT" name)"

fresh
mkdir -p "$TMP/ws/a/b"
touch "$TMP/ws/a/pnpm-lock.yaml"
detect ./a/b/
assert_eq "leading ./ and trailing / are normalised" pnpm "$(output_of "$OUT" name)"
assert_eq "nested lockfile path" a/pnpm-lock.yaml "$(output_of "$OUT" lockfile)"

# Cache resolution
fresh
touch "$TMP/ws/package-lock.json"
detect . auto auto
assert_eq "cache=auto with npm lockfile enables npm cache" npm "$(output_of "$OUT" cache)"
assert_eq "cache=auto points at the real lockfile" package-lock.json "$(output_of "$OUT" cache-dependency-path)"

fresh
touch "$TMP/ws/bun.lock"
detect . auto auto
assert_eq "cache=auto stays empty for bun" "" "$(output_of "$OUT" cache)"

fresh
echo '{}' > "$TMP/ws/package.json"
detect . auto auto
assert_eq "cache=auto without a lockfile stays empty" "" "$(output_of "$OUT" cache)"

fresh
mkdir -p "$TMP/ws/pkg"
touch "$TMP/ws/yarn.lock"
detect pkg auto yarn
assert_eq "explicit cache uses parent lockfile" yarn.lock "$(output_of "$OUT" cache-dependency-path)"

fresh
detect pkg npm npm
assert_eq "explicit cache without lockfile keeps the legacy glob" "pkg/**/package-lock.json" "$(output_of "$OUT" cache-dependency-path)"

fresh
detect . npm npm
assert_eq "legacy glob at the workspace root" "**/package-lock.json" "$(output_of "$OUT" cache-dependency-path)"

fresh
detect . auto ""
assert_eq "empty cache stays empty" "" "$(output_of "$OUT" cache)"

# Invalid input fails with an error annotation
fresh
if (cd "$TMP/ws" && WORKDIR=. PM_INPUT=poetry GITHUB_OUTPUT="$TMP/o" bash "$ROOT/scripts/detect-package-manager.sh" > "$TMP/err.txt" 2>&1); then
  fail "unsupported package-manager input is rejected"
else
  assert_contains "unsupported package-manager input is rejected" "$TMP/err.txt" "::error::package-manager must be one of"
fi

finish

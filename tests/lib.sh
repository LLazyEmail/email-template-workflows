#!/usr/bin/env bash
# Tiny assertion helpers shared by the test scripts. Source this file.
# Compatible with bash 3.2 (macOS) and Git Bash (Windows).

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  echo "  ok   $1"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "  FAIL $1"
  [ -z "${2:-}" ] || echo "       $2"
  # On GitHub Actions, also raise an annotation so the failure is visible on the run page.
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error::test failed: $1${2:+ ($2)}"
  fi
}

# assert_eq <description> <expected> <actual>
assert_eq() {
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1" "expected '$2', got '$3'"
  fi
}

# assert_file <description> <path>  (file exists and is not empty)
assert_file() {
  if [ -s "$2" ]; then
    pass "$1"
  else
    fail "$1" "missing or empty: $2"
  fi
}

# assert_no_file <description> <path>
assert_no_file() {
  if [ ! -e "$2" ]; then
    pass "$1"
  else
    fail "$1" "should not exist: $2"
  fi
}

# assert_contains <description> <file> <fixed string>
assert_contains() {
  if grep -qF -- "$3" "$2" 2> /dev/null; then
    pass "$1"
  else
    fail "$1" "'$3' not found in $2"
  fi
}

# output_of <file> <key>: last value written for key in a GITHUB_OUTPUT file
output_of() {
  sed -n "s/^$2=//p" "$1" | tail -n 1
}

finish() {
  echo
  echo "passed: $PASS, failed: $FAIL"
  [ "$FAIL" -eq 0 ]
}

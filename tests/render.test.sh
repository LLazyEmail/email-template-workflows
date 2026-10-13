#!/usr/bin/env bash
# Tests for scripts/render.sh against a copy of fixtures/consumer.
# Package-manager cases run only for the package managers that are installed.
# shellcheck disable=SC2016 # single quotes are intentional: these strings are run later by bash -c
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$ROOT/tests/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# new_project: fresh copy of the fixture consumer in $PROJ
new_project() {
  rm -rf "$TMP/proj"
  cp -R "$ROOT/fixtures/consumer" "$TMP/proj"
  rm -rf "$TMP/proj/generated"
  PROJ="$TMP/proj"
  GH_OUT="$TMP/github_output"
  GH_SUMMARY="$TMP/github_summary"
  : > "$GH_OUT"
  : > "$GH_SUMMARY"
}

# render [VAR=value ...]: runs render.sh in $PROJ with the given environment.
# Sets RC and LOG (path of the combined stdout/stderr).
render() {
  LOG="$TMP/render.log"
  RC=0
  (
    cd "$PROJ"
    env GITHUB_OUTPUT="$GH_OUT" GITHUB_STEP_SUMMARY="$GH_SUMMARY" "$@" \
      bash "$ROOT/scripts/render.sh"
  ) > "$LOG" 2>&1 || RC=$?
}

count_li() {
  grep -c '<li>' "$1" || true
}

echo "render.sh: script mode"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/newsletter.html
assert_eq "single template succeeds" 0 "$RC"
assert_file "single template writes the HTML" "$PROJ/generated/newsletter.html"
assert_file "index.html is written next to the output" "$PROJ/generated/index.html"
assert_eq "html-count output" 1 "$(output_of "$GH_OUT" html-count)"
assert_eq "html-path output" "./generated/newsletter.html" "$(output_of "$GH_OUT" html-path)"
assert_eq "artifact-dir output" "./generated" "$(output_of "$GH_OUT" artifact-dir)"
assert_eq "failed-count output" 0 "$(output_of "$GH_OUT" failed-count)"
assert_contains "rendered.txt lists the file" "$PROJ/generated/rendered.txt" "generated/newsletter.html"
assert_no_file "no failed.txt without failures" "$PROJ/generated/failed.txt"
assert_contains "job summary lists the file" "$GH_SUMMARY" '`generated/newsletter.html`'
assert_contains "validate-email ran by default" "$LOG" "validate-email"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/newsletter.html JOB_SUMMARY=false
assert_eq "job-summary: false writes nothing" 0 "$(wc -c < "$GH_SUMMARY" | tr -d '[:space:]')"

new_project
render TEMPLATES="# the catalogue
src/newsletter.md : generated/newsletter.html

   src/welcome.md:generated/welcome.html
" ARTIFACT_DIRECTORY=generated
assert_eq "templates: comments, blanks and spaces are handled" 0 "$RC"
assert_eq "templates: both rendered" 2 "$(output_of "$GH_OUT" html-count)"
assert_eq "templates: index has both entries" 2 "$(count_li "$PROJ/generated/index.html")"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html EXTRA_ARGS="--title Hello"
assert_contains "extra-args are forwarded" "$PROJ/generated/n.html" "<title>Hello</title>"

new_project
touch "$PROJ/should-not-match.txt"
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html EXTRA_ARGS="--title *"
assert_contains "extra-args are not glob-expanded" "$PROJ/generated/n.html" "<title>*</title>"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html VALIDATE_SCRIPT=
assert_eq "validate-script empty skips validation" 0 "$RC"
if grep -q "validate-email" "$LOG"; then fail "validation was skipped"; else pass "validation was skipped"; fi

new_project
(cd "$PROJ" && node -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync("package.json","utf8"));delete p.scripts["validate-email"];fs.writeFileSync("package.json",JSON.stringify(p))')
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html
assert_eq "missing validate script still succeeds" 0 "$RC"
assert_contains "missing validate script warns" "$LOG" "::warning::validate-script 'validate-email' is not defined"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html VALIDATE_COMMAND=false
assert_eq "failing validate-command fails the render" 1 "$RC"

echo "render.sh: argument styles"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_SCRIPT=build-positional INPUT_FLAG= OUTPUT_FLAG= VALIDATE_SCRIPT=
assert_eq "positional arguments" 0 "$RC"
assert_contains "positional script produced the file" "$PROJ/generated/n.html" "<title>positional</title>"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_SCRIPT=build-equals INPUT_FLAG=--src= OUTPUT_FLAG=--dest= VALIDATE_SCRIPT=
assert_eq "--flag=value arguments" 0 "$RC"
assert_contains "equals-style script produced the file" "$PROJ/generated/n.html" "<title>equals</title>"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_SCRIPT=build-env VALIDATE_SCRIPT=
assert_eq "script that reads EMAIL_TEMPLATE_* env vars" 0 "$RC"
assert_contains "env script produced the file" "$PROJ/generated/n.html" "<title>env</title>"

echo "render.sh: build-command"

new_project
render TEMPLATES="src/newsletter.md:generated/a.html
src/welcome.md:generated/b.html" \
  BUILD_COMMAND='mkdir -p "$(dirname "$EMAIL_TEMPLATE_OUTPUT")" && { printf "<!doctype html><p>"; cat "$EMAIL_TEMPLATE_INPUT"; printf "</p>\n"; } > "$EMAIL_TEMPLATE_OUTPUT"' \
  VALIDATE_COMMAND='grep -q "<p>" "$EMAIL_TEMPLATE_OUTPUT"' ARTIFACT_DIRECTORY=generated
assert_eq "build-command renders every template" 0 "$RC"
assert_eq "build-command html-count" 2 "$(output_of "$GH_OUT" html-count)"
assert_file "build-command wrote the first file" "$PROJ/generated/a.html"
assert_file "build-command wrote the second file" "$PROJ/generated/b.html"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_COMMAND='exit 3'
assert_eq "failing build-command fails the render" 1 "$RC"

echo "render.sh: command mode"

new_project
render COMMAND="npm run render-all" ARTIFACT_DIRECTORY=generated
assert_eq "command mode succeeds" 0 "$RC"
assert_eq "command mode html-count" 2 "$(output_of "$GH_OUT" html-count)"
assert_eq "command mode index entries" 2 "$(count_li "$PROJ/generated/index.html")"

new_project
render COMMAND='mkdir -p out/deep/er && echo "<p>x</p>" > out/deep/er/x.html && echo "<p>y</p>" > out/y.html' ARTIFACT_DIRECTORY=out
assert_eq "command mode finds HTML at any depth" 2 "$(output_of "$GH_OUT" html-count)"
assert_contains "nested links are relative to the artifact directory" "$PROJ/out/index.html" 'href="deep/er/x.html"'

new_project
render COMMAND="npm run render-all"
assert_eq "command mode without artifact-directory fails" 1 "$RC"
assert_contains "command mode explains the missing artifact-directory" "$LOG" "command mode requires artifact-directory"

new_project
render COMMAND="true" ARTIFACT_DIRECTORY=nowhere
assert_eq "command mode with a missing directory fails" 1 "$RC"
assert_contains "missing directory is explained" "$LOG" "does not exist after the command ran"

new_project
render COMMAND="exit 2" ARTIFACT_DIRECTORY=generated
assert_eq "failing command fails the render" 1 "$RC"

echo "render.sh: failures and configuration errors"

new_project
render TEMPLATES="src/newsletter.md:generated/a.html
src/missing.md:generated/b.html
src/welcome.md:generated/c.html" ARTIFACT_DIRECTORY=generated
assert_eq "fail-fast (default) stops at the first failure" 1 "$RC"
assert_no_file "fail-fast writes no index" "$PROJ/generated/index.html"

new_project
render TEMPLATES="src/newsletter.md:generated/a.html
src/missing.md:generated/b.html
src/welcome.md:generated/c.html" ARTIFACT_DIRECTORY=generated FAIL_FAST=false
assert_eq "fail-fast false keeps going" 0 "$RC"
assert_eq "fail-fast false renders the good ones" 2 "$(output_of "$GH_OUT" html-count)"
assert_eq "fail-fast false counts failures" 1 "$(output_of "$GH_OUT" failed-count)"
assert_contains "failed.txt names the failed template" "$PROJ/generated/failed.txt" "src/missing.md"
assert_contains "index.html lists failures" "$PROJ/generated/index.html" "src/missing.md"
assert_contains "job summary lists failures" "$GH_SUMMARY" '**Failed (1):**'

new_project
render TEMPLATES="src/missing.md:generated/a.html" ARTIFACT_DIRECTORY=generated FAIL_FAST=false
assert_eq "all templates failing is an error even with fail-fast false" 1 "$RC"

new_project
render TEMPLATES="src/newsletter.md-generated/a.html"
assert_eq "invalid template line fails" 1 "$RC"
assert_contains "invalid template line is explained" "$LOG" "invalid template line"

new_project
render TEMPLATES="src/newsletter.md:src/newsletter.md"
assert_eq "identical input and output fails" 1 "$RC"

new_project
render
assert_eq "nothing configured fails" 1 "$RC"
assert_contains "nothing configured is explained" "$LOG" "No templates rendered"

echo "render.sh: failure explanations"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_SCRIPT=no-such-script
assert_eq "missing build-script fails before rendering" 1 "$RC"
assert_contains "pre-flight names the missing script" "$LOG" "::error::build-script not found"
assert_no_file "pre-flight renders nothing" "$PROJ/generated/n.html"

new_project
render SINGLE_INPUT=src/missing.md SINGLE_OUTPUT=generated/n.html
assert_contains "render failure has an error annotation" "$LOG" "::error::render failed for src/missing.md"
assert_contains "render failure shows the script that ran" "$LOG" "npm run build-email exited non-zero"
assert_contains "render failure lists next checks" "$LOG" "Common next checks:"
if grep -q '\\n' "$LOG"; then fail "explanations print real newlines"; else pass "explanations print real newlines"; fi

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_COMMAND='exit 3'
assert_contains "build-command failure names the command" "$LOG" "The build-command exited non-zero"
assert_contains "build-command failure gives command-specific advice" "$LOG" "Does the build-command run on its own"

new_project
cat > "$PROJ/fail-tsc.js" << 'EOF'
console.error("scripts/samples/hackernoon/hackernoon-data.ts(1,42): error TS2307: Cannot find module '../../../src/types.js'")
process.exit(1)
EOF
node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync("'"$PROJ"'/package.json","utf8")); p.scripts["fail-tsc"]="node fail-tsc.js"; fs.writeFileSync("'"$PROJ"'/package.json", JSON.stringify(p,null,2));'
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_SCRIPT=fail-tsc
assert_eq "tsc-style failure fails the render" 1 "$RC"
assert_contains "annotation includes the tsc cause" "$LOG" "::error::render failed for src/newsletter.md: scripts/samples/hackernoon/hackernoon-data.ts(1,42): error TS2307: Cannot find module"
assert_contains "failure block repeats the cause" "$LOG" "Cause:"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_COMMAND='true' VALIDATE_SCRIPT=
assert_eq "a build that writes nothing fails" 1 "$RC"
assert_contains "empty output is explained" "$LOG" "::error::empty or missing output"

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html VALIDATE_COMMAND=false
assert_contains "validation failure is explained" "$LOG" "::error::validation failed for generated/n.html"

new_project
render COMMAND="exit 2" ARTIFACT_DIRECTORY=generated
assert_contains "command failure is explained" "$LOG" "::error::command mode failed"

echo "render.sh: HTML escaping in index.html"

new_project
printf 'x' > "$PROJ/src/a&b.md"
render SINGLE_INPUT='src/a&b.md' SINGLE_OUTPUT='generated/a&b.html' VALIDATE_SCRIPT=
assert_eq "an ampersand in a file name renders" 0 "$RC"
assert_contains "index.html escapes &" "$PROJ/generated/index.html" 'a&amp;b.html'

# < and > are not allowed in Windows file names (Git Bash maps them to other
# characters instead of failing), so only test them on Unix.
new_project
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) windows=true ;;
  *) windows=false ;;
esac
if [ "$windows" = false ] && printf 'x' > "$PROJ/src/a<b>.md" 2> /dev/null; then
  render SINGLE_INPUT='src/a<b>.md' SINGLE_OUTPUT='generated/a<b>.html' VALIDATE_SCRIPT=
  assert_eq "angle brackets in a file name render" 0 "$RC"
  assert_contains "index.html escapes < and >" "$PROJ/generated/index.html" 'a&lt;b&gt;.html'
else
  echo "  skip angle brackets (not usable in file names here)"
fi

echo "render.sh: size warning"

new_project
{ printf '<!doctype html><p>'; head -c 3000 /dev/zero | tr '\0' 'x'; printf '</p>\n'; } > "$PROJ/src/big.md"
render SINGLE_INPUT=src/big.md SINGLE_OUTPUT=generated/big.html SIZE_LIMIT_KB=1 VALIDATE_SCRIPT=
assert_eq "oversized email still succeeds" 0 "$RC"
assert_contains "oversized email warns" "$LOG" "::warning file=./generated/big.html,title=Email may be clipped::"

new_project
{ printf '<!doctype html><p>'; head -c 3000 /dev/zero | tr '\0' 'x'; printf '</p>\n'; } > "$PROJ/src/big.md"
render SINGLE_INPUT=src/big.md SINGLE_OUTPUT=generated/big.html SIZE_LIMIT_KB=0 VALIDATE_SCRIPT=
if grep -q "Email may be clipped" "$LOG"; then fail "size-limit-kb 0 disables the warning"; else pass "size-limit-kb 0 disables the warning"; fi

new_project
render SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html SIZE_LIMIT_KB=abc
assert_eq "non-numeric size-limit-kb is rejected" 1 "$RC"

echo "render.sh: package managers"

for pm in npm pnpm yarn bun; do
  if ! command -v "$pm" > /dev/null 2>&1; then
    echo "  skip $pm (not installed)"
    continue
  fi
  new_project
  render PM="$pm" SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html EXTRA_ARGS="--title FromPM"
  assert_eq "$pm: script mode succeeds" 0 "$RC"
  assert_contains "$pm: arguments reach the build script" "$PROJ/generated/n.html" "<title>FromPM</title>"
  assert_contains "$pm: validation ran" "$LOG" "validate-email"

  new_project
  render PM="$pm" SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html BUILD_SCRIPT=build-equals INPUT_FLAG=--src= OUTPUT_FLAG=--dest= VALIDATE_SCRIPT=
  assert_eq "$pm: --flag=value style succeeds" 0 "$RC"

  new_project
  render PM="$pm" COMMAND="$pm run render-all" ARTIFACT_DIRECTORY=generated
  assert_eq "$pm: command mode succeeds" 0 "$RC"
done

new_project
render PM=poetry SINGLE_INPUT=src/newsletter.md SINGLE_OUTPUT=generated/n.html
assert_eq "unsupported package manager fails" 1 "$RC"

finish

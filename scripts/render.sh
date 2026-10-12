#!/usr/bin/env bash
# Renders email templates, writes index.html / rendered.txt (and failed.txt) into
# the artifact directory, and sets the step outputs.
#
# Run from the working directory. Configuration comes from the environment (see
# action.yml, which maps each action input to one variable below).
#
# Compatible with bash 3.2 (macOS) and Git Bash (Windows): no mapfile, no
# namerefs, no empty-array expansion under `set -u`.
#
# Caution: `set -e` is ignored inside a function that is called from an `if`
# condition, so render_one and validate_one end every command with `|| return 1`.
set -euo pipefail

PM=${PM:-npm}
COMMAND=${COMMAND:-}
BUILD_COMMAND=${BUILD_COMMAND:-}
BUILD_SCRIPT=${BUILD_SCRIPT:-build-email}
VALIDATE_COMMAND=${VALIDATE_COMMAND:-}
VALIDATE_SCRIPT=${VALIDATE_SCRIPT-validate-email} # unset = default, empty = skip
TEMPLATES=${TEMPLATES:-}
SINGLE_INPUT=${SINGLE_INPUT:-}
SINGLE_OUTPUT=${SINGLE_OUTPUT:-}
EXTRA_ARGS=${EXTRA_ARGS:-}
INPUT_FLAG=${INPUT_FLAG---input} # unset = default, empty = positional argument
OUTPUT_FLAG=${OUTPUT_FLAG---output}
VALIDATE_FLAG=${VALIDATE_FLAG---file}
ARTIFACT_DIRECTORY=${ARTIFACT_DIRECTORY:-}
ARTIFACT_NAME=${ARTIFACT_NAME:-}
WORKDIR=${WORKDIR:-.}
FAIL_FAST=${FAIL_FAST:-true}
SIZE_LIMIT_KB=${SIZE_LIMIT_KB:-102}
JOB_SUMMARY=${JOB_SUMMARY:-true}
OUT=${GITHUB_OUTPUT:-/dev/null}
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}

case "$SIZE_LIMIT_KB" in
  '' | *[!0-9]*)
    echo "::error::size-limit-kb must be a whole number of kilobytes (0 disables the check), got '$SIZE_LIMIT_KB'"
    exit 1
    ;;
esac

if ! command -v node > /dev/null 2>&1; then
  echo "::error::node must be on PATH to index the rendered files. Keep setup-node: true or install Node.js before this action."
  exit 1
fi

has_script() {
  [ -f package.json ] || return 1
  node -e 'const s=(require(require("path").resolve("package.json")).scripts)||{};process.exit(Object.prototype.hasOwnProperty.call(s,process.argv[1])?0:1)' "$1" 2> /dev/null
}

# Path of $2 relative to directory $1, always with forward slashes.
rel() {
  node -e 'console.log(require("path").relative(process.argv[1],process.argv[2]).split("\\").join("/"))' "$1" "$2"
}

esc() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

trim() {
  printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Print an ::error:: annotation followed by a short block that says what failed
# and what to check next. $2 may contain \n sequences.
explain_failure() {
  local what=$1 detail=$2
  echo ""
  echo "::error::${what}"
  echo "----------------------------------------"
  printf '%b\n' "$detail"
  echo "----------------------------------------"
  echo "Common next checks:"
  if [ -n "$BUILD_COMMAND" ]; then
    echo "  - Does the build-command run on its own with EMAIL_TEMPLATE_INPUT and EMAIL_TEMPLATE_OUTPUT set?"
  else
    echo "  - Does the script exist in package.json?"
    echo "  - Does the script accept the arguments the action passes (see input-flag and output-flag)?"
  fi
  echo "  - Did it write a non-empty HTML file at the expected path?"
  echo "  - Look at the lines above for the tool's own output (tsc, node, mjml, ...)."
  echo ""
}

# Run package.json script $1 with the remaining arguments, using the package
# manager's own argument-forwarding syntax.
run_script() {
  local name=$1
  shift
  case "$PM" in
    npm) npm run "$name" -- "$@" ;;
    yarn) yarn run "$name" "$@" ;;
    pnpm) pnpm run "$name" "$@" ;;
    bun) bun run "$name" "$@" ;;
    *)
      echo "::error::unsupported package manager '$PM'"
      return 1
      ;;
  esac
}

# Append one value to ARGS using the configured flag style:
#   "--input"  -> --input value
#   "--input=" -> --input=value
#   ""         -> value (positional)
ARGS=()
add_flag() {
  local flag=$1 value=$2
  if [ -z "$flag" ]; then
    ARGS+=("$value")
  else
    case "$flag" in
      *=) ARGS+=("$flag$value") ;;
      *) ARGS+=("$flag" "$value") ;;
    esac
  fi
}

# extra-args is split on whitespace (never glob-expanded, never evaluated).
EXTRA=()
if [ -n "$EXTRA_ARGS" ]; then
  EXTRA_ARGS=${EXTRA_ARGS//$'\n'/ }
  read -r -a EXTRA <<< "$EXTRA_ARGS"
fi

validate_one() {
  local output=$1
  if [ -n "$VALIDATE_COMMAND" ]; then
    bash -c "$VALIDATE_COMMAND" || return 1
  elif [ -n "$VALIDATE_SCRIPT" ]; then
    if has_script "$VALIDATE_SCRIPT"; then
      ARGS=()
      add_flag "$VALIDATE_FLAG" "$output"
      run_script "$VALIDATE_SCRIPT" "${ARGS[@]}" || return 1
    elif [ -f package.json ]; then
      echo "::warning::validate-script '$VALIDATE_SCRIPT' is not defined in package.json; skipping validation"
    fi
  fi
  return 0
}

# Render one template. Exposes EMAIL_TEMPLATE_INPUT / EMAIL_TEMPLATE_OUTPUT to
# build-command, validate-command and to the npm scripts.
render_one() {
  local input=$1 output=$2
  FAIL_WHAT=""
  FAIL_DETAIL=""
  export EMAIL_TEMPLATE_INPUT=$input
  export EMAIL_TEMPLATE_OUTPUT=$output
  if [ -n "$BUILD_COMMAND" ]; then
    echo "  build-command: $BUILD_COMMAND"
    if ! bash -c "$BUILD_COMMAND"; then
      FAIL_WHAT="render failed for $input"
      FAIL_DETAIL="The build-command exited non-zero while rendering:\n  input:   $input\n  output:  $output\n  command: $BUILD_COMMAND\n\nThe command's own output is above. Fix the command or its dependencies, then re-run."
      return 1
    fi
  else
    ARGS=()
    add_flag "$INPUT_FLAG" "$input"
    add_flag "$OUTPUT_FLAG" "$output"
    if [ "${#EXTRA[@]}" -gt 0 ]; then
      ARGS+=("${EXTRA[@]}")
    fi
    echo "  script: $PM run $BUILD_SCRIPT ${ARGS[*]}"
    if ! run_script "$BUILD_SCRIPT" "${ARGS[@]}"; then
      FAIL_WHAT="render failed for $input"
      FAIL_DETAIL="$PM run $BUILD_SCRIPT exited non-zero while rendering:\n  input:  $input\n  output: $output\n\nThe script's own output is above (for example a tsc error, a missing template, or a non-zero exit from the node process). Fix the consumer script or its dependencies, then re-run."
      return 1
    fi
  fi
  if ! validate_one "$output"; then
    FAIL_WHAT="validation failed for $output"
    FAIL_DETAIL="Validation exited non-zero on:\n  $output\n\nCheck the validation output above."
    return 1
  fi
  if [ ! -s "$output" ]; then
    FAIL_WHAT="empty or missing output"
    FAIL_DETAIL="The build succeeded but did not produce a non-empty file at:\n  $output\n\nConfirm it actually writes that path (it may ignore the output argument or write elsewhere)."
    return 1
  fi
  return 0
}

FAIL_WHAT=""
FAIL_DETAIL=""
rendered=()
failed=()
outdir=""

if [ -n "$COMMAND" ]; then
  if [ -z "$ARTIFACT_DIRECTORY" ]; then
    explain_failure "missing artifact-directory" "command mode requires artifact-directory so the action knows which folder to index."
    exit 1
  fi
  echo "running command: $COMMAND"
  if ! bash -c "$COMMAND"; then
    explain_failure "command mode failed" "The command exited non-zero:\n  $COMMAND\n\nNo HTML was indexed. Check the command output above."
    exit 1
  fi
  outdir=$ARTIFACT_DIRECTORY
  if [ ! -d "$outdir" ]; then
    explain_failure "artifact-directory not found" "artifact-directory '$outdir' does not exist after the command ran. It is relative to working-directory."
    exit 1
  fi
  while IFS= read -r f; do
    rendered+=("$f")
  done < <(find "$outdir" -type f -name '*.html' ! -name 'index.html' | sort)
else
  if [ -z "$BUILD_COMMAND" ]; then
    if [ -z "$BUILD_SCRIPT" ]; then
      explain_failure "missing build-script" "Script mode requires a build-script input. Set build-command or command instead if you do not have one."
      exit 1
    fi
    if ! has_script "$BUILD_SCRIPT"; then
      explain_failure "build-script not found" "Script '$BUILD_SCRIPT' is not defined in package.json.\n\nAdd it, or set build-script to a script that exists, or use build-command or command."
      exit 1
    fi
  fi
  pairs=()
  if [ -n "$TEMPLATES" ]; then
    while IFS= read -r raw || [ -n "$raw" ]; do
      pairs+=("$raw")
    done <<< "$TEMPLATES"
  elif [ -n "$SINGLE_INPUT" ] || [ -n "$SINGLE_OUTPUT" ]; then
    pairs+=("$SINGLE_INPUT:$SINGLE_OUTPUT")
  fi

  for raw in "${pairs[@]:-}"; do
    line=$(trim "$raw")
    [ -n "$line" ] || continue
    case "$line" in \#*) continue ;; esac
    input=$(trim "${line%%:*}")
    output=$(trim "${line#*:}")
    if [ -z "$input" ] || [ -z "$output" ] || [ "$input" = "$output" ]; then
      explain_failure "invalid template line" "Expected input:output, and the two must differ. Got: $line"
      exit 1
    fi
    echo "::group::render $input -> $output"
    if render_one "$input" "$output"; then
      echo "::endgroup::"
      rendered+=("$output")
    else
      echo "::endgroup::"
      explain_failure "${FAIL_WHAT:-render failed for $input}" "${FAIL_DETAIL:-Rendering $input -> $output failed.}"
      failed+=("$input")
      if [ "$FAIL_FAST" = "true" ]; then
        exit 1
      fi
    fi
  done

  if [ -n "$ARTIFACT_DIRECTORY" ]; then
    outdir=$ARTIFACT_DIRECTORY
  elif [ "${#rendered[@]}" -gt 0 ]; then
    outdir=$(dirname "${rendered[0]}")
  fi
fi

if [ "${#rendered[@]}" -eq 0 ]; then
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "::error::All ${#failed[@]} template(s) failed to render."
  else
    explain_failure "No templates rendered" "Set command plus artifact-directory, templates, input plus output, or build-command with templates. Nothing was written."
  fi
  exit 1
fi

mkdir -p "$outdir"

size_kb() {
  awk -v b="$1" 'BEGIN { printf "%.1f", b / 1024 }'
}

# Per-file size in bytes, same order as rendered[].
sizes=()
for f in "${rendered[@]}"; do
  bytes=$(wc -c < "$f" | tr -d '[:space:]')
  sizes+=("$bytes")
  if [ "$SIZE_LIMIT_KB" -gt 0 ] && [ "$bytes" -gt $((SIZE_LIMIT_KB * 1024)) ]; then
    echo "::warning file=$WORKDIR/$f,title=Email may be clipped::$f is $(size_kb "$bytes") KB, over the size-limit-kb of $SIZE_LIMIT_KB KB. Gmail clips messages larger than about 102 KB."
  fi
done

{
  echo '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Rendered emails</title></head><body>'
  echo '<h1>Rendered emails</h1>'
  echo '<ul>'
  i=0
  for f in "${rendered[@]}"; do
    name=$(rel "$outdir" "$f" | esc)
    echo "<li><a href=\"$name\">$name</a> <small>($(size_kb "${sizes[$i]}") KB)</small></li>"
    i=$((i + 1))
  done
  echo '</ul>'
  if [ "${#failed[@]}" -gt 0 ]; then
    echo '<h2>Failed</h2>'
    echo '<ul>'
    for f in "${failed[@]}"; do
      echo "<li>$(printf '%s' "$f" | esc)</li>"
    done
    echo '</ul>'
  fi
  echo '</body></html>'
} > "$outdir/index.html"

printf '%s\n' "${rendered[@]}" > "$outdir/rendered.txt"
if [ "${#failed[@]}" -gt 0 ]; then
  printf '%s\n' "${failed[@]}" > "$outdir/failed.txt"
else
  rm -f "$outdir/failed.txt"
fi

if [ "$JOB_SUMMARY" = "true" ]; then
  {
    if [ -n "$ARTIFACT_NAME" ]; then
      echo "### Rendered emails (\`$ARTIFACT_NAME\`)"
    else
      echo "### Rendered emails"
    fi
    echo
    echo "| File | Size |"
    echo "| --- | ---: |"
    i=0
    for f in "${rendered[@]}"; do
      echo "| \`$f\` | $(size_kb "${sizes[$i]}") KB |"
      i=$((i + 1))
    done
    if [ "${#failed[@]}" -gt 0 ]; then
      echo
      echo "**Failed (${#failed[@]}):**"
      for f in "${failed[@]}"; do
        echo "- \`$f\`"
      done
    fi
    echo
  } >> "$SUMMARY"
fi

{
  echo "html-count=${#rendered[@]}"
  echo "html-path=$WORKDIR/${rendered[0]}"
  echo "artifact-dir=$WORKDIR/$outdir"
  echo "failed-count=${#failed[@]}"
} >> "$OUT"

echo "rendered ${#rendered[@]} template(s) into $outdir (${#failed[@]} failed)"

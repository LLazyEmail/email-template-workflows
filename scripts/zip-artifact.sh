#!/usr/bin/env bash
# Creates a zip of the rendered artifact directory so consumers can download
# a single archive (useful for the planned online editor and general reuse).
#
# Environment:
#   ARTIFACT_DIR  - directory to zip (required)
#   ZIP_NAME      - base name for the zip (default: templates)
#
# The zip is written inside ARTIFACT_DIR as <ZIP_NAME>.zip and is excluded
# from itself. Existing zip of the same name is replaced.
set -euo pipefail

ARTIFACT_DIR=${ARTIFACT_DIR:-}
ZIP_NAME=${ZIP_NAME:-templates}

if [ -z "$ARTIFACT_DIR" ] || [ ! -d "$ARTIFACT_DIR" ]; then
  echo "::error::zip-artifact: ARTIFACT_DIR '$ARTIFACT_DIR' is missing or not a directory"
  exit 1
fi

# Prefer zip; fall back to python (always available on the runners we support).
cd "$ARTIFACT_DIR"
rm -f "${ZIP_NAME}.zip"

if command -v zip > /dev/null 2>&1; then
  # -r recursive, -q quiet, exclude the zip itself if present
  zip -r -q "${ZIP_NAME}.zip" . -x "${ZIP_NAME}.zip"
else
  python3 - << 'PY'
import os, sys, zipfile
name = os.environ.get("ZIP_NAME", "templates") + ".zip"
root = "."
with zipfile.ZipFile(name, "w", zipfile.ZIP_DEFLATED) as z:
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            path = os.path.join(dirpath, fn)
            if path == "./".__add__(name) or path == name:
                continue
            arc = os.path.relpath(path, root)
            z.write(path, arc)
print("wrote", name)
PY
fi

echo "zipped $(pwd)/${ZIP_NAME}.zip"

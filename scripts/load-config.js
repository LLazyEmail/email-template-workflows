#!/usr/bin/env node
// Load a config file (JSON or simple YAML) and print shell assignments for
// keys that match action inputs. Explicit environment values win: a key is
// only emitted when the corresponding env var is empty or still at its default.
//
// Usage: node scripts/load-config.js <path>
// Prints lines like: PRODUCT_NAME=docs
// Unknown keys are warned on stderr. Invalid files exit 1.
'use strict';

const fs = require('fs');
const path = require('path');

// kebab-case input name -> { env, default }
// Defaults must match action.yml and the ${VAR:-default} lines in render.sh.
const MAP = {
  'input': { env: 'SINGLE_INPUT', def: '' },
  'output': { env: 'SINGLE_OUTPUT', def: '' },
  'templates': { env: 'TEMPLATES', def: '' },
  'command': { env: 'COMMAND', def: '' },
  'file-pattern': { env: 'FILE_PATTERN', def: '*.html' },
  'build-command': { env: 'BUILD_COMMAND', def: '' },
  'build-script': { env: 'BUILD_SCRIPT', def: 'build-email' },
  'input-flag': { env: 'INPUT_FLAG', def: '--input' },
  'output-flag': { env: 'OUTPUT_FLAG', def: '--output' },
  'extra-args': { env: 'EXTRA_ARGS', def: '' },
  'validate-command': { env: 'VALIDATE_COMMAND', def: '' },
  'validate-script': { env: 'VALIDATE_SCRIPT', def: 'validate-email' },
  'validate-flag': { env: 'VALIDATE_FLAG', def: '--file' },
  'fail-fast': { env: 'FAIL_FAST', def: 'true' },
  'size-limit-kb': { env: 'SIZE_LIMIT_KB', def: '102' },
  'artifact-directory': { env: 'ARTIFACT_DIRECTORY', def: '' },
  'artifact-name': { env: 'ARTIFACT_NAME', def: '' },
  'job-summary': { env: 'JOB_SUMMARY', def: 'true' },
  'product-name': { env: 'PRODUCT_NAME', def: 'emails' },
  'comment-heading': { env: 'COMMENT_HEADING', def: '' },
};

function parseSimpleYaml(text) {
  const out = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, '').trim();
    if (!line) continue;
    const m = line.match(/^([A-Za-z0-9_-]+)\s*:\s*(.*)$/);
    if (!m) {
      console.error(`::error::config file has a line that is not key: value: ${raw}`);
      process.exit(1);
    }
    let value = m[2].trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    out[m[1]] = value;
  }
  return out;
}

const file = process.argv[2];
if (!file) {
  console.error('::error::load-config.js needs a config file path');
  process.exit(1);
}
if (!fs.existsSync(file)) {
  console.error(`::error::config file not found: ${file}`);
  process.exit(1);
}

const text = fs.readFileSync(file, 'utf8');
let data;
try {
  if (text.trim().startsWith('{')) {
    data = JSON.parse(text);
  } else {
    data = parseSimpleYaml(text);
  }
} catch (err) {
  console.error(`::error::config file is not valid JSON or simple YAML: ${err.message}`);
  process.exit(1);
}

if (data === null || typeof data !== 'object' || Array.isArray(data)) {
  console.error('::error::config file must be a mapping of input names to values');
  process.exit(1);
}

for (const key of Object.keys(data)) {
  if (!MAP[key]) {
    console.error(`::warning::config file has unknown key '${key}' (ignored)`);
    continue;
  }
  const { env, def } = MAP[key];
  const current = process.env[env];
  // Explicit action input / environment wins. Only fill when unset or still default.
  if (current !== undefined && current !== '' && current !== def) continue;
  const value = data[key];
  if (value === undefined || value === null || value === '') continue;
  // Shell-safe single-quoted assignment.
  const escaped = String(value).replace(/'/g, "'\\''");
  process.stdout.write(`${env}='${escaped}'\n`);
}

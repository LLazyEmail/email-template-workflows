'use strict';

// Posts or updates the "Rendered emails" pull request comment.
// Loaded by actions/github-script from action.yml; also unit-tested in
// tests/pr-comment.test.js with a mocked GitHub client.

const fs = require('fs');
const path = require('path');

const MARKER_PREFIX = '<!-- email-template-workflows';
const MAX_LISTED = 100;
// Headings written by older versions of this action and of hand-written
// workflows. A comment with one of them (and no marker) is adopted once.
const LEGACY_HEADINGS = [
  '### Rendered emails',
  '### Sandbox HTML',
  '### Fixture emails rendered',
  '### Fixture email rendered',
  '### Emails rendered',
];

// Keep the key safe inside an HTML comment and a heading.
function sanitizeKey(key) {
  return String(key || '')
    .trim()
    .replace(/[^A-Za-z0-9_.]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function readLines(file) {
  if (!fs.existsSync(file)) {
    return [];
  }
  return fs
    .readFileSync(file, 'utf8')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function bullets(lines) {
  const shown = lines.slice(0, MAX_LISTED).map((line) => `- \`${line}\``);
  if (lines.length > MAX_LISTED) {
    shown.push(`- …and ${lines.length - MAX_LISTED} more (see \`index.html\` in the artifact)`);
  }
  return shown;
}

function buildBody({ key, rendered, failed, runUrl, artifactName, artifactUrl, uploaded }) {
  const marker = key ? `${MARKER_PREFIX}:${key} -->` : `${MARKER_PREFIX} -->`;
  const heading = key ? `### Rendered emails (${key})` : '### Rendered emails';
  const artifactLine = artifactUrl
    ? `- Artifact: [\`${artifactName}\`](${artifactUrl})`
    : `- Artifact: \`${artifactName}\``;
  return [
    marker,
    heading,
    '',
    failed.length > 0
      ? 'This PR rendered email templates, but some of them failed.'
      : 'This PR rendered email templates.',
    '',
    ...bullets(rendered),
    ...(failed.length > 0 ? ['', '**Failed to render:**', ...bullets(failed)] : []),
    '',
    `- Run: ${runUrl}`,
    ...(uploaded ? [artifactLine, '', 'Open the run → **Artifacts** → download → open `index.html`.'] : []),
  ].join('\n');
}

async function run({ github, context, core, env = process.env }) {
  const key = sanitizeKey(env.COMMENT_KEY);
  const marker = key ? `${MARKER_PREFIX}:${key} -->` : `${MARKER_PREFIX} -->`;
  const artifactDir = env.ARTIFACT_DIR;
  const runUrl = `${env.GITHUB_SERVER_URL}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;

  const body = buildBody({
    key,
    rendered: readLines(path.join(artifactDir, 'rendered.txt')),
    failed: readLines(path.join(artifactDir, 'failed.txt')),
    runUrl,
    artifactName: env.ARTIFACT_NAME,
    artifactUrl: env.ARTIFACT_URL,
    uploaded: env.UPLOAD_ARTIFACT === 'true',
  });

  const issueNumber = context.payload.pull_request.number;
  try {
    const comments = await github.paginate(github.rest.issues.listComments, {
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: issueNumber,
      per_page: 100,
    });
    const isBot = (c) => c.user?.type === 'Bot';
    const hasAnyMarker = (c) => Boolean(c.body?.includes(MARKER_PREFIX));
    let existing = comments.find((c) => isBot(c) && c.body?.includes(marker));
    if (!existing && !key) {
      // Adopt a pre-marker comment, but never one that belongs to a keyed run.
      existing = comments.find(
        (c) => isBot(c) && !hasAnyMarker(c) && LEGACY_HEADINGS.some((heading) => c.body?.includes(heading)),
      );
    }
    if (existing) {
      await github.rest.issues.updateComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        comment_id: existing.id,
        body,
      });
    } else {
      await github.rest.issues.createComment({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: issueNumber,
        body,
      });
    }
  } catch (error) {
    // A comment is a convenience. Dependabot runs and some forks only get a
    // read-only token; do not fail the build for that.
    if (error && (error.status === 403 || error.status === 404)) {
      core.warning(
        `Could not post the pull request comment (HTTP ${error.status}). ` +
          'Give the job `pull-requests: write`, or set `pr-comment: false`. ' +
          'The rendered files are still in the artifact and the job summary.',
      );
      return;
    }
    throw error;
  }
}

module.exports = run;
module.exports.buildBody = buildBody;
module.exports.sanitizeKey = sanitizeKey;

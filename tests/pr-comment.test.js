'use strict';

// Unit tests for scripts/pr-comment.js with a mocked GitHub client.
// Run: node tests/pr-comment.test.js

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const run = require('../scripts/pr-comment.js');

let passed = 0;
let failed = 0;

async function test(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`  ok   ${name}`);
  } catch (error) {
    failed += 1;
    console.log(`  FAIL ${name}\n       ${error.message}`);
  }
}

function artifactDir({ rendered = ['generated/a.html'], failed: failedList = [] } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pr-comment-'));
  fs.writeFileSync(path.join(dir, 'rendered.txt'), rendered.join('\n') + '\n');
  if (failedList.length > 0) {
    fs.writeFileSync(path.join(dir, 'failed.txt'), failedList.join('\n') + '\n');
  }
  return dir;
}

// In-memory stand-in for the pieces of the GitHub client the script uses.
function mockGithub(existing = [], failWith = null) {
  const state = { comments: existing.slice(), created: [], updated: [] };
  const maybeFail = () => {
    if (failWith) {
      throw Object.assign(new Error('boom'), { status: failWith });
    }
  };
  return {
    state,
    paginate: async () => {
      maybeFail();
      return state.comments;
    },
    rest: {
      issues: {
        listComments: () => {},
        createComment: async (args) => {
          maybeFail();
          state.created.push(args);
        },
        updateComment: async (args) => {
          maybeFail();
          state.updated.push(args);
        },
      },
    },
  };
}

const context = {
  repo: { owner: 'o', repo: 'r' },
  runId: 42,
  payload: { pull_request: { number: 7 } },
};

function makeCore() {
  const warnings = [];
  return { warnings, warning: (m) => warnings.push(m) };
}

function envFor(dir, extra = {}) {
  return {
    GITHUB_SERVER_URL: 'https://github.com',
    ARTIFACT_DIR: dir,
    ARTIFACT_NAME: 'rendered-email',
    ARTIFACT_URL: 'https://example.test/artifact/1',
    UPLOAD_ARTIFACT: 'true',
    ...extra,
  };
}

const bot = (id, body) => ({ id, body, user: { type: 'Bot' } });
const human = (id, body) => ({ id, body, user: { type: 'User' } });

(async () => {
  console.log('pr-comment.js');

  await test('creates a comment when none exists', async () => {
    const github = mockGithub();
    await run({ github, context, core: makeCore(), env: envFor(artifactDir()) });
    assert.strictEqual(github.state.created.length, 1);
    assert.strictEqual(github.state.updated.length, 0);
    const { body, issue_number: issue } = github.state.created[0];
    assert.strictEqual(issue, 7);
    assert.ok(body.startsWith('<!-- email-template-workflows -->\n### Rendered emails\n'));
    assert.ok(body.includes('- `generated/a.html`'));
    assert.ok(body.includes('https://github.com/o/r/actions/runs/42'));
    assert.ok(body.includes('[`rendered-email`](https://example.test/artifact/1)'));
  });

  await test('updates the comment that carries the hidden marker', async () => {
    const github = mockGithub([bot(5, '<!-- email-template-workflows -->\nold')]);
    await run({ github, context, core: makeCore(), env: envFor(artifactDir()) });
    assert.strictEqual(github.state.created.length, 0);
    assert.strictEqual(github.state.updated[0].comment_id, 5);
  });

  await test('adopts a legacy comment without a marker', async () => {
    const github = mockGithub([bot(9, '### Sandbox HTML\nold')]);
    await run({ github, context, core: makeCore(), env: envFor(artifactDir()) });
    assert.strictEqual(github.state.updated[0].comment_id, 9);
  });

  await test('ignores comments written by people', async () => {
    const github = mockGithub([human(3, '<!-- email-template-workflows -->\nquoted')]);
    await run({ github, context, core: makeCore(), env: envFor(artifactDir()) });
    assert.strictEqual(github.state.created.length, 1);
  });

  await test('a keyed run creates its own comment next to the default one', async () => {
    const github = mockGithub([bot(5, '<!-- email-template-workflows -->\n### Rendered emails')]);
    await run({ github, context, core: makeCore(), env: envFor(artifactDir(), { COMMENT_KEY: 'marketing' }) });
    assert.strictEqual(github.state.updated.length, 0);
    assert.strictEqual(github.state.created.length, 1);
    const body = github.state.created[0].body;
    assert.ok(body.startsWith('<!-- email-template-workflows:marketing -->\n### Rendered emails (marketing)\n'));
  });

  await test('a keyed run updates only its own comment', async () => {
    const github = mockGithub([
      bot(1, '<!-- email-template-workflows -->\n### Rendered emails'),
      bot(2, '<!-- email-template-workflows:marketing -->\n### Rendered emails (marketing)'),
      bot(3, '<!-- email-template-workflows:marketing-eu -->\n### Rendered emails (marketing-eu)'),
    ]);
    await run({ github, context, core: makeCore(), env: envFor(artifactDir(), { COMMENT_KEY: 'marketing' }) });
    assert.strictEqual(github.state.updated.length, 1);
    assert.strictEqual(github.state.updated[0].comment_id, 2);
  });

  await test('an unkeyed run never adopts a keyed comment through the legacy heading', async () => {
    const github = mockGithub([bot(2, '<!-- email-template-workflows:marketing -->\n### Rendered emails (marketing)')]);
    await run({ github, context, core: makeCore(), env: envFor(artifactDir()) });
    assert.strictEqual(github.state.updated.length, 0);
    assert.strictEqual(github.state.created.length, 1);
  });

  await test('the key is sanitised for use inside an HTML comment', async () => {
    assert.strictEqual(run.sanitizeKey('a--b --> c'), 'a-b-c');
    assert.strictEqual(run.sanitizeKey('  '), '');
    assert.strictEqual(run.sanitizeKey(undefined), '');
    assert.strictEqual(run.sanitizeKey('welcome_email.v2'), 'welcome_email.v2');
  });

  await test('failed templates are listed', async () => {
    const github = mockGithub();
    const dir = artifactDir({ failed: ['src/missing.md'] });
    await run({ github, context, core: makeCore(), env: envFor(dir) });
    const body = github.state.created[0].body;
    assert.ok(body.includes('but some of them failed'));
    assert.ok(body.includes('**Failed to render:**'));
    assert.ok(body.includes('- `src/missing.md`'));
  });

  await test('a long list is truncated', async () => {
    const github = mockGithub();
    const many = Array.from({ length: 150 }, (_, i) => `generated/${i}.html`);
    await run({ github, context, core: makeCore(), env: envFor(artifactDir({ rendered: many })) });
    const body = github.state.created[0].body;
    assert.ok(body.includes('- `generated/99.html`'));
    assert.ok(!body.includes('- `generated/100.html`'));
    assert.ok(body.includes('…and 50 more'));
  });

  await test('without an uploaded artifact the artifact line is omitted', async () => {
    const github = mockGithub();
    await run({ github, context, core: makeCore(), env: envFor(artifactDir(), { UPLOAD_ARTIFACT: 'false' }) });
    const body = github.state.created[0].body;
    assert.ok(!body.includes('Artifact:'));
    assert.ok(!body.includes('index.html'));
  });

  await test('a 403 becomes a warning, not a failure', async () => {
    const github = mockGithub([], 403);
    const core = makeCore();
    await run({ github, context, core, env: envFor(artifactDir()) });
    assert.strictEqual(core.warnings.length, 1);
    assert.ok(core.warnings[0].includes('pull-requests: write'));
  });

  await test('other API errors still fail the step', async () => {
    const github = mockGithub([], 500);
    await assert.rejects(() => run({ github, context, core: makeCore(), env: envFor(artifactDir()) }), /boom/);
  });

  console.log(`\npassed: ${passed}, failed: ${failed}`);
  process.exit(failed === 0 ? 0 : 1);
})();

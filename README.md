# email-template-workflows

Reusable GitHub Action that installs your project's dependencies, renders email HTML with **whatever you already use** (an npm script, MJML, Maizzle, pandoc, a catalog CLI), uploads a browsable artifact, writes a job summary, and on a pull request posts or updates one comment.

Works with **npm, yarn, pnpm and bun**, on Linux, macOS and Windows runners, in single-package repositories and monorepos.

Pin `LLazyEmail/email-template-workflows@v1`. That floating major tag tracks the latest `v1.x` release. Immutable patch tags stay where they were published. For the strongest supply-chain guarantee, pin the full commit SHA of a release instead and keep it current with Renovate or Dependabot.

## Quick start

Pick the render mode that matches your project.

**Command mode**: you have a CLI that renders a folder or catalog.

```yaml
permissions:
  contents: read
  pull-requests: write

steps:
  - uses: actions/checkout@v7
  - uses: LLazyEmail/email-template-workflows@v1
    with:
      working-directory: .
      command: npx generate-template --all --out=generated
      artifact-directory: generated
```

**Script mode**: you have an npm script that takes an input and an output path.

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: LLazyEmail/email-template-workflows@v1
    with:
      working-directory: .
      build-script: build-email
      input: src/welcome.md
      output: generated/welcome.html
      validate-script: ""
```

**Build-command mode**: you have a tool that is not an npm script (MJML, pandoc, a Python script...). The action runs your command once per template and hands it the paths as environment variables.

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: LLazyEmail/email-template-workflows@v1
    with:
      working-directory: .
      templates: |
        emails/welcome.mjml:dist/welcome.html
        emails/invoice.mjml:dist/invoice.html
      build-command: npx mjml "$EMAIL_TEMPLATE_INPUT" -o "$EMAIL_TEMPLATE_OUTPUT"
      validate-script: ""
      artifact-directory: dist
```

## What it covers

| You have | Set | Notes |
| --- | --- | --- |
| npm, yarn, pnpm or bun | nothing, or `package-manager` | `auto` reads the `packageManager` field, then the lockfile (also in parent folders), then falls back to npm. yarn and pnpm run through Corepack, bun through `oven-sh/setup-bun`. |
| A monorepo | `working-directory` | Lockfile and `packageManager` are found in parent folders. `cache: auto` caches from the root lockfile. |
| A build script that takes `--input` and `--output` | `build-script` | The default style. |
| A script with other argument names | `input-flag`, `output-flag` | `--src` passes `--src <path>`, `--src=` passes `--src=<path>`, empty passes the path positionally. |
| A script that reads environment variables | nothing | `EMAIL_TEMPLATE_INPUT` and `EMAIL_TEMPLATE_OUTPUT` are always set. |
| A CLI that is not an npm script | `build-command` | Runs once per template. |
| A CLI that renders a whole folder | `command` | Runs once; every `*.html` file under `artifact-directory` is indexed. |
| Shared code to build first | `prebuild-command` | Runs after install, before rendering, in every mode. |
| A private registry | `registry-url`, `registry-scope` | Authenticate with `NODE_AUTH_TOKEN` in the job's `env`. |
| A Node version file | `node-version-file` | `.nvmrc`, `.node-version` or `.tool-versions`. |
| One broken template among many | `fail-fast: false` | Renders the rest, uploads and comments, then fails the job. |
| Two sets of emails in one pull request | `comment-key` | Each key gets its own comment. |
| No pull request (schedule, push) | `pr-comment: false` | The job summary and the artifact still list everything. |
| Gmail clipping | `size-limit-kb` | Warns when an email is over 102 KB (the default). |

## Real-world example

[`LLazyEmail/_playing_with_lit`](https://github.com/LLazyEmail/_playing_with_lit) renders 15 templates with a job matrix, one job per template: [`render-email-action.yml`](https://github.com/LLazyEmail/_playing_with_lit/blob/main/.github/workflows/render-email-action.yml). Line-by-line explanation: [docs/real-world-example.md](docs/real-world-example.md). More in [`examples/`](examples/):

- [`script-mode-single.yml`](examples/script-mode-single.yml), [`script-mode-templates.yml`](examples/script-mode-templates.yml), [`matrix-script-mode.yml`](examples/matrix-script-mode.yml)
- [`command-mode.yml`](examples/command-mode.yml)
- [`mjml-build-command.yml`](examples/mjml-build-command.yml): any CLI, no npm script
- [`pnpm-monorepo.yml`](examples/pnpm-monorepo.yml): workspace, root lockfile, filtered install
- [`keep-going-two-comments.yml`](examples/keep-going-two-comments.yml): `fail-fast: false` and `comment-key`
- [`scheduled-summary-only.yml`](examples/scheduled-summary-only.yml): no pull request

## For AI agents and LLM tools

- [`docs/agent-playbook.md`](docs/agent-playbook.md): start here. Inspect the repository, choose a mode, write the workflow, verify. Copy-paste recipes and a table that maps log messages to fixes.
- [`llms.txt`](llms.txt): short index of this repository for LLMs.
- [`AGENTS.md`](AGENTS.md): decision rules, input precedence, gotchas and a verification checklist for agents that add this Action to a repository.
- [`action.yml`](action.yml): source of truth for inputs, outputs and defaults.

## Usage

The caller job needs `pull-requests: write` to post the comment. Without it (a read-only token, Dependabot, some forks) the action logs a warning and carries on; the job summary and the artifact are unaffected. Set `pr-comment: false` to skip the comment entirely. Comments are always skipped for pull requests from forks.

```yaml
permissions:
  contents: read
  pull-requests: write

steps:
  - uses: actions/checkout@v7
  - uses: LLazyEmail/email-template-workflows@v1
    with:
      working-directory: .
      command: npx generate-template --all --out=generated
      artifact-directory: generated
      artifact-name: rendered-email
```

The artifact is a directory; the comment links the run and tells you to open `index.html`. `index.html` lists every rendered file with its size.

The comment heading is `### Rendered emails`. A later run updates the existing bot comment instead of adding another one. It also replaces an older `### Sandbox HTML` or fixture comment. With `comment-key` the heading is `### Rendered emails (<key>)` and each key is tracked separately.

## Inputs

### What to render

Set `command`, or `templates`, or both `input` and `output`. The action writes `index.html` and `rendered.txt` (and `failed.txt` when something failed) into the artifact directory and uploads that directory.

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `command` | no | empty | Command mode. Shell command run after install. Ignores `templates`, `input`, `output`, `build-command`, `build-script`, `validate-command`, `validate-script` and `extra-args`. Needs `artifact-directory`. |
| `templates` | no | empty | Multiline `input:output` pairs, relative to `working-directory`. Blank lines and `#` lines are skipped. Paths must not contain a colon. Ignored when `command` is set. |
| `input` | no | empty | Single source path, relative to `working-directory` |
| `output` | no | empty | Single HTML path, relative to `working-directory` |

### How to render each template

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `build-command` | no | empty | Shell command run once per template, with `$EMAIL_TEMPLATE_INPUT` and `$EMAIL_TEMPLATE_OUTPUT` set. Takes precedence over `build-script`. |
| `build-script` | no | `build-email` | `package.json` script that compiles one email. Called with the input and output paths and `extra-args`. |
| `input-flag` | no | `--input` | How the input path is passed to `build-script`: `--input` is `--input <path>`, `--input=` is `--input=<path>`, empty is positional. |
| `output-flag` | no | `--output` | How the output path is passed. Same styles as `input-flag`. |
| `extra-args` | no | empty | Appended after the input and output for every template. Split on whitespace, never glob-expanded. Do not put values with spaces in it. `build-script` only. |
| `validate-command` | no | empty | Shell command run after each template is built, with `$EMAIL_TEMPLATE_OUTPUT` set. Non-zero fails that template. Takes precedence over `validate-script`. |
| `validate-script` | no | `validate-email` | `package.json` script that validates one compiled file. Empty skips validation. If the script is not defined in `package.json`, validation is skipped with a warning. |
| `validate-flag` | no | `--file` | How the compiled file is passed to `validate-script`. Same styles as `input-flag`. |
| `fail-fast` | no | `true` | `true` stops at the first failing template. `false` renders the rest, uploads, comments, then fails the job at the end. |
| `size-limit-kb` | no | `102` | Warn when a rendered email is larger than this many KB. Gmail clips messages over about 102 KB. `0` disables the check. |

### Where and with what to run

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `working-directory` | no | `generated` | Directory that contains `package.json`, relative to the workspace. Every path input is relative to it. Use `.` for a repository root. |
| `package-manager` | no | `auto` | `auto`, `npm`, `yarn`, `pnpm` or `bun`. See [What it covers](#what-it-covers). |
| `package-manager-version` | no | empty | Version to activate, for example `9.15.0` for pnpm. Empty uses the `packageManager` field, or the latest. |
| `install-command` | no | empty | Command that installs dependencies in `working-directory`. Empty runs `<package-manager> install`. Use `npm ci`, `pnpm install --frozen-lockfile` or `yarn install --immutable` to enforce the lockfile. |
| `skip-install` | no | `false` | `true` skips dependency installation. |
| `prebuild-command` | no | empty | Shell command run after install and before rendering, in `working-directory`. Runs in every render mode. |
| `setup-node` | no | `true` | `false` skips `actions/setup-node` and uses the Node.js already on the runner. Node.js must be on `PATH` either way. |
| `node-version` | no | `24` | Node.js version. Ignored when `node-version-file` is set. |
| `node-version-file` | no | empty | `.nvmrc`, `.node-version` or `.tool-versions`, relative to the workspace root. |
| `cache` | no | empty | `npm`, `yarn` or `pnpm`, or `auto` to follow the detected package manager when a lockfile exists. Empty disables caching. |
| `registry-url` | no | empty | Registry to configure for the install, for example `https://npm.pkg.github.com`. |
| `registry-scope` | no | empty | Scope to authenticate against `registry-url`, for example `@my-org`. |

### What to publish

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `upload-artifact` | no | `true` | Upload the HTML directory |
| `artifact-name` | no | `rendered-email` | Artifact name. Must be unique within a run, so give each matrix job its own. |
| `artifact-directory` | no | empty | Directory to index and upload, relative to `working-directory`. Empty uses the directory of the first rendered file. Required when `command` is set. |
| `retention-days` | no | `14` | Days to keep the uploaded artifact |
| `job-summary` | no | `true` | Write the rendered files and their sizes to the job summary. Needs no token permission. |
| `pr-comment` | no | `true` | Post or update the pull request comment. No-op unless the event is `pull_request`. Skipped for forks. A read-only token logs a warning instead of failing. |
| `comment-key` | no | empty | Gives this call its own comment, so several calls in one pull request do not overwrite each other. |

## Outputs

| Output | Meaning |
| --- | --- |
| `html-path` | Path to the first generated HTML file, relative to the workspace |
| `html-count` | Number of HTML files rendered |
| `failed-count` | Number of templates that failed. Always `0` unless `fail-fast` is `false`. |
| `artifact-dir` | The directory that was indexed and uploaded, relative to the workspace |
| `artifact-url` | Link to the uploaded artifact. Empty when `upload-artifact` is not `true`. |
| `package-manager` | The package manager that was used: `npm`, `yarn`, `pnpm` or `bun` |

## What your build receives

For every template, in `build-script`, `build-command`, `validate-script` and `validate-command`:

| Variable | Value |
| --- | --- |
| `EMAIL_TEMPLATE_INPUT` | The input path, relative to `working-directory` |
| `EMAIL_TEMPLATE_OUTPUT` | The output path, relative to `working-directory` |

Your own `env:` on the job is passed through as usual, so secrets such as `NODE_AUTH_TOKEN` or `GITHUB_TOKEN` reach the install and the build.

## Failure handling

- A template that fails to build, fails validation, or writes an empty file fails the job with an error annotation naming it. The annotation also includes the first cause line from the command (for example `error TS2307: Cannot find module ...`), and the failure block reprints that cause plus the last lines of the command.
- With `fail-fast: false` the other templates still render. The artifact, the job summary and the pull request comment are produced, then the job fails. `failed.txt` in the artifact and a **Failed to render** section in the comment list what broke.
- If every template fails there is nothing to publish and the job fails immediately.
- An email over `size-limit-kb` produces a warning annotation, not a failure.

## Development

```sh
bash tests/detect-package-manager.test.sh   # package manager, lockfile and cache resolution
bash tests/render.test.sh                   # every render mode, with each installed package manager
node tests/pr-comment.test.js               # the pull request comment, with a mocked GitHub client
python3 tests/check-action.py               # action.yml, docs, snippets, links and pinned actions stay in sync
```

CI runs these on Linux, macOS (including the system bash 3.2) and Windows, lints the YAML, shell scripts and workflows (`yamllint`, `shellcheck`, `actionlint`), and renders `fixtures/consumer` through `uses: ./` with each package manager. `.github/workflows/fixture-render.yml` has one job per capability.

Every `uses:` in this repository is pinned to a full commit SHA with a version comment. `renovate.json` keeps those pins current.

## Consumer contract

The action detects the package manager and runs `install-command` (default `<package-manager> install`) inside `working-directory`. Without `command`, it then renders each template with `build-command` if set, otherwise with `<package-manager> run <build-script>` and the input and output paths. With `command`, it runs that shell command once and indexes `artifact-directory`.

[`_playing_with_lit`](https://github.com/LLazyEmail/_playing_with_lit) already uses script mode with `--input` and `--output`.

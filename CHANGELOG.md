# Changelog

All notable changes to `LLazyEmail/email-template-workflows` are listed here.

## [Unreleased]

### Added (agent documentation)
- `docs/agent-playbook.md`: a step-by-step procedure for AI agents that add the Action to a repository (inspect, choose a mode, write the workflow, verify), a decision flowchart, eleven recipes, a table that maps log messages to fixes, and hard rules.
- `AGENTS.md` now opens with a "Start here" section and the five rules that matter most.
- `tests/check-action.py` checks every YAML snippet in the README and the playbook: it must parse, and any call to this Action may only use inputs that exist in `action.yml`. It also checks that relative links in the docs point at files that exist.

### Added (universal support)
- Package managers: `package-manager` (`auto`, `npm`, `yarn`, `pnpm`, `bun`) and `package-manager-version`. `auto` reads the `packageManager` field, then the lockfile in `working-directory` and its parents (monorepos), then falls back to npm. yarn and pnpm run through Corepack, bun through `oven-sh/setup-bun`.
- `build-command` and `validate-command`: run any tool once per template, with `EMAIL_TEMPLATE_INPUT` and `EMAIL_TEMPLATE_OUTPUT` set. These variables are now set for `build-script` and `validate-script` too.
- `input-flag`, `output-flag` and `validate-flag`: pass paths as `--flag value`, `--flag=value` or positionally. This resolves the cause of issue #21.
- `prebuild-command`, `skip-install`, `setup-node`, `node-version-file`, `registry-url` and `registry-scope`.
- `cache: auto`, which follows the detected package manager and its real lockfile path, including a lockfile in a parent folder.
- `fail-fast: false`: render the remaining templates after a failure, still upload and comment, then fail the job at the end. New `failed-count` output and `failed.txt` in the artifact.
- `size-limit-kb` (default 102): warning annotation when an email is large enough for Gmail to clip it. `index.html` shows each file's size.
- `job-summary` (default `true`): the rendered files and sizes in the job summary. Works without any token permission.
- `comment-key`: a separate pull request comment per call.
- New output `package-manager`.
- `scripts/` (`detect-package-manager.sh`, `render.sh`, `pr-comment.js`) holds the logic that used to be inline in `action.yml`. The clearer failure messages from #24 (error annotation, failing template and command, next checks, build-script pre-flight check) live in `scripts/render.sh` and also apply to `build-command` and `validate-command`.
- `tests/` with unit tests for all three scripts and `tests/check-action.py`, which keeps `action.yml`, the README and the pinned actions in sync.
- `.github/workflows/ci.yml` (yamllint, shellcheck, actionlint, tests on Linux, macOS including bash 3.2, and Windows), `.yamllint.yml`, and new examples for MJML, a pnpm workspace, two comments with `fail-fast: false`, and a scheduled run.
- The fixture workflow now covers `build-command`, every flag style, `fail-fast: false`, npm/pnpm/yarn/bun, macOS and Windows, and `packageManager` detection.

### Changed (universal support)
- `package-manager` defaults to `auto`. A repository with only a `pnpm-lock.yaml`, `yarn.lock` or `bun.lock` is now installed and run with that tool instead of npm. Set `package-manager: npm` to keep the old behavior.
- `install-command` now defaults to empty, which runs `<package-manager> install` (still `npm install` for npm). Use `skip-install: true` to skip the install; an empty `install-command` no longer means "skip".
- A missing `pull-requests: write` permission or a read-only token (Dependabot) now logs a warning instead of failing the job.
- Command mode checks `artifact-directory` before running the command, and runs it with `bash -c` instead of a login shell, which could reset `PATH` set by `setup-node`.
- Every `uses:` is pinned to a full commit SHA, and `renovate.json` keeps the pins current. Workflows have explicit minimal permissions and timeouts.
- `fixture-render.yml` runs on pushes to `main` and on pull requests, not on every push to every branch.

### Fixed (universal support)
- `cache: ""` did not disable caching. `actions/setup-node` v5 and later turns npm caching on by itself when `package.json` has a `packageManager` field, and fails without a lockfile. The action now always passes `package-manager-cache: false`.
- `extra-args` was glob-expanded by the shell. It is now split on whitespace only.
- `index.html` links used backslashes on Windows runners.
- The legacy-heading fallback could take over a `comment-key` comment.
- The scripts avoid `mapfile` and bare empty-array expansion, so they run on the bash 3.2 that macOS ships.

### Added
- Clearer console explanations when a render or validate step fails. Instead of a bare `Process completed with exit code 1`, the action now prints an `::error::` annotation and a short block that names the failing template/script, shows the command that was run, and lists common next checks.
- Pre-flight check that the `build-script` exists in `package.json` before any template is rendered.
- Explicit failure message when a build script exits 0 but does not produce a non-empty HTML file at the expected output path.

### Added
- `install-command` input (default `npm install`) so consumers can use `npm ci` or another installer.
- `retention-days` input (default `14`) for the uploaded artifact.
- `artifact-dir` and `artifact-url` outputs.
- The pull request comment links directly to the uploaded artifact.
- Hidden marker `<!-- email-template-workflows -->` in the pull request comment, used to find it again.
- `AGENTS.md`, `llms.txt`, `CLAUDE.md` and `.github/copilot-instructions.md` for AI agents and LLM tools.
- `examples/` with script, templates, command and matrix workflows, and `docs/real-world-example.md`.
- `.github/workflows/release.yml`, which moves the floating major tag (for example `v1`) when a release is published.

### Changed
- `validate-script` is now skipped with a warning when the script is not defined in `package.json`. It used to fail the job.
- Command mode indexes `*.html` files at any depth, and `index.html` links use paths relative to `artifact-directory`. File names are HTML-escaped.
- `cache-dependency-path` follows the `cache` input (`package-lock.json`, `yarn.lock` or `pnpm-lock.yaml`).
- The comment step is skipped for pull requests from forks, which only get a read-only token.
- The comment step reads all pages of existing comments, and prefers the hidden marker over the legacy headings.

### Fixed
- A duplicate comment could be posted on pull requests with more than 30 comments.
- yarn and pnpm caching looked for `package-lock.json`.

### Removed
- `example-workflow.yml` at the repository root. It posted its own comment on top of the built-in one. Use `examples/` instead.

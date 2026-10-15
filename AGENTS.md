# AGENTS.md

Guidance for AI coding agents that work **in** this repository, or that **add this Action to another repository**.

## What this is

`LLazyEmail/email-template-workflows` is a GitHub **composite Action** (`action.yml` at the repo root, shell and one `github-script` file, no compiled code). It:

1. Detects the package manager (`scripts/detect-package-manager.sh`): npm, yarn, pnpm or bun.
2. Activates it (Corepack for yarn and pnpm, `oven-sh/setup-bun` for bun) and sets up Node.js (`actions/setup-node`).
3. Runs `install-command` (default `<package-manager> install`) in `working-directory`, then `prebuild-command` if set.
4. Renders email HTML (`scripts/render.sh`): `command` once, or `build-command` / `<pm> run <build-script>` per template.
5. Writes `index.html`, `rendered.txt` (and `failed.txt`) into the artifact directory, and a job summary.
6. Uploads that directory as an artifact (`actions/upload-artifact`, `retention-days` default 14).
7. On `pull_request`, creates or updates one bot comment headed `### Rendered emails` (`scripts/pr-comment.js`).

Current tag to use from other repos: `LLazyEmail/email-template-workflows@v1`.

## Start here

- **Adding this Action to another repository?** Follow [`docs/agent-playbook.md`](docs/agent-playbook.md): inspect the repo, choose a mode, write the workflow, verify. It has copy-paste recipes and a table that maps log messages to fixes.
- **Changing this repository?** Skip to [Working on this repository](#working-on-this-repository).

The five rules that matter most when adding the Action:

1. Look at the repository first (lockfile, `package.json` scripts, template files, `.npmrc`, existing workflows). Never invent a script, flag, path or input.
2. Pick one render mode: `command` (one command renders everything), `build-command` (a CLI renders one file; use `$EMAIL_TEMPLATE_INPUT` and `$EMAIL_TEMPLATE_OUTPUT`), or `build-script` (an npm script takes input and output paths).
3. Set `working-directory` (the default `generated` is rarely right) and `artifact-directory` (where the HTML really is). Paths are relative to `working-directory`.
4. Pin `@v1`, put `actions/checkout` first, and give every call its own `artifact-name`.
5. Do not report success until a pull request run shows the artifact, the job summary and a single `### Rendered emails` comment, or say plainly that you could not check.

## Adding the Action to another repository: decision rules

Follow in order and stop at the first match.

1. **Does the consumer have a CLI or script that renders a whole folder or catalog?** (for example `npx generate-template --all --out=generated`, `npm run sandbox`)
   Use **command mode**: set `command` and `artifact-directory`. Do not set `input`/`output`/`templates`; they are ignored.
2. **Does the consumer render one template at a time with a tool that is not an npm script?** (MJML, Maizzle, pandoc, a Python script)
   Use **`build-command`** with `templates` (or `input` + `output`). The command reads `$EMAIL_TEMPLATE_INPUT` and `$EMAIL_TEMPLATE_OUTPUT`. Quote them.
3. **Does the consumer have an npm script that accepts the input and output paths?**
   Use **script mode**.
   - One template: `input` + `output`.
   - Several in one job: `templates` (one `input:output` per line).
   - Many, with separate pass/fail per template: a job `matrix` with one `input`/`output`/`build-script` per row (see `examples/matrix-script-mode.yml`).
   - Different argument names: set `input-flag` / `output-flag` (`--src`, `--src=`, or empty for positional). A script that reads environment variables needs nothing: `EMAIL_TEMPLATE_INPUT` and `EMAIL_TEMPLATE_OUTPUT` are always set.
4. **None of these fit?** Use command mode with the exact command the project already uses. Do not invent flags.

## Required caller setup

- Add `actions/checkout@v7` before the Action.
- Permissions on the caller job:
  - `contents: read`
  - `pull-requests: write` only if `pr-comment` is left at its default (`true`). Without it, or with a read-only token (Dependabot), the comment is skipped with a warning and the job still passes. Pull requests from forks are skipped.
  - `packages: read` plus `GITHUB_TOKEN` in `env` if the consumer installs private GitHub Packages (for example `@llazyemail/*` via `.npmrc`), or use `registry-url` with `NODE_AUTH_TOKEN`.
- Set `working-directory` explicitly. The default is `generated`, which is rarely right. Use `.` when `package.json` is at the repo root.

## Input precedence and defaults

| Condition | Effect |
| --- | --- |
| `command` set | `templates`, `input`, `output`, `build-command`, `build-script`, `validate-command`, `validate-script`, `extra-args` are all ignored. `artifact-directory` is **required** (the step exits 1 without it). |
| `build-command` set | Wins over `build-script`, `input-flag`, `output-flag` and `extra-args`. |
| `validate-command` set | Wins over `validate-script`. |
| `templates` set | `input` and `output` are ignored. |
| neither | `input` and `output` are both required. |
| nothing renders | The step fails with "No templates rendered". |

Defaults worth knowing: `working-directory=generated`, `package-manager=auto`, `install-command=""` (runs `<pm> install`), `build-script=build-email`, `validate-script=validate-email`, `input-flag=--input`, `output-flag=--output`, `validate-flag=--file`, `node-version=24`, `cache=""` (no cache), `fail-fast=true`, `size-limit-kb=102`, `job-summary=true`, `upload-artifact=true`, `artifact-name=rendered-email`, `retention-days=14`, `pr-comment=true`.

Outputs: `html-path` (first rendered file), `html-count`, `failed-count`, `artifact-dir`, `artifact-url` (empty when `upload-artifact` is not `true`) and `package-manager`.

## Gotchas (check these before reporting success)

- **`validate-script` runs by default** in script and build-command modes (`<pm> run validate-email --file <output>`). If the script is not defined in the consumer's `package.json`, validation is skipped with a warning. Set `validate-script: ""` to skip it silently. If the script exists but fails, the job fails.
- **`templates` lines split on the first `:`**. Paths containing a colon will break. Lines starting with `#` and blank lines are skipped. `input` and `output` must differ.
- **`input`/`output` are relative to `working-directory`**, and so is `artifact-directory`. `node-version-file` is relative to the workspace root.
- **Command mode indexes `*.html` files at any depth** in `artifact-directory`, excluding `index.html`. Links in `index.html` are relative to `artifact-directory`.
- **Matrix jobs and several calls share one PR comment** unless each has a `comment-key`. Either set `pr-comment: false` in matrix workflows or give every call its own `comment-key`. Always give each call a unique `artifact-name`.
- **`extra-args` is split on whitespace**, never glob-expanded or evaluated. Do not put values with spaces in it. It applies to `build-script` only.
- **The package manager is auto-detected** from the `packageManager` field, then the lockfile (also in parent folders), then npm. Set `package-manager` if a repository has several lockfiles.
- **Installs use `install-command`, default `<pm> install`.** Set `install-command: npm ci` (or `pnpm install --frozen-lockfile`, `yarn install --immutable`) to enforce the lockfile. `cache` only controls the `setup-node` cache: `auto` follows the detected package manager when a lockfile exists, empty never caches. The action always passes `package-manager-cache: false` to `setup-node`, so nothing is cached unless `cache` says so.
- **`fail-fast: false`** keeps rendering after a failure and fails the job at the very end, after the artifact and the comment.
- **Node.js must be on `PATH`** even with `setup-node: false`, because the action uses it to index the output.
- **Pin `@v1`.** Do not use `@main`. Immutable patch tags (`v1.x.y`) exist when exact reproducibility is needed.
- **Known limitation, now solvable:** issue #21 tracks Lit scripts that did not accept `--input`/`--output`. Use `input-flag` / `output-flag`, read `EMAIL_TEMPLATE_*` in the script, or use `build-command`.
- **Failure messages:** when a render, validate, or command step fails, the action prints an `::error::` annotation plus a short block naming the failing template or script, the command that was run, and common next checks. A bare `Process completed with exit code 1` means the failure happened before the render step's own wrapper (for example during install).

## Verifying a change

Step 4 of the [playbook](docs/agent-playbook.md#step-4-verify) is the checklist: the YAML parses, the scripts and paths exist, `artifact-directory` matches the build, permissions fit, and a pull request run shows an artifact, a job summary and one `### Rendered emails` comment.

## Working on this repository

- `action.yml` is the single source of truth. When inputs, defaults, or outputs change, update `README.md`, `llms.txt`, this file and `CHANGELOG.md` in the same commit. `python3 tests/check-action.py` fails if an input or output is missing from the README.
- The logic lives in `scripts/`: `detect-package-manager.sh`, `render.sh` and `pr-comment.js`. Keep the shell compatible with bash 3.2 (macOS) and Git Bash (Windows): no `mapfile`, no namerefs, no bare `"${array[@]}"` on a possibly empty array. Remember that `set -e` is ignored inside a function called from an `if`, so end commands with `|| return 1`.
- Run the tests before committing: `bash tests/detect-package-manager.test.sh`, `bash tests/render.test.sh`, `node tests/pr-comment.test.js`, `python3 tests/check-action.py`. Add a test with every behaviour change.
- `fixtures/consumer` and `.github/workflows/fixture-render.yml` exercise every mode via `uses: ./`. Jobs that must not comment set `pr-comment: false` so a PR gets one comment, not several. Keep that.
- `.github/workflows/ci.yml` lints (yamllint, shellcheck, actionlint) and runs the tests on Linux, macOS and Windows.
- Every `uses:` in `action.yml` and `.github/workflows/` is pinned to a full commit SHA with a `# vX.Y.Z` comment. `renovate.json` keeps them current. Do not replace a SHA with a tag.
- `.github/workflows/release.yml` moves the floating major tag (`v1`) when a `vMAJOR.MINOR.PATCH` release is published. Publish releases instead of moving tags by hand.
- Do not add a build step or compiled code. The Action is composite YAML plus shell scripts and one `github-script` file.
- Keep the comment markers stable: the hidden `<!-- email-template-workflows -->` marker (keyed runs use `<!-- email-template-workflows:KEY -->`), `### Rendered emails`, and the legacy headings. The update-in-place behavior depends on them.

## Reference

- Inputs, outputs, defaults: `action.yml`
- Human-oriented docs: `README.md`
- Machine-oriented index: `llms.txt`
- Release notes: `CHANGELOG.md`
- Real consumer: `LLazyEmail/_playing_with_lit` → `.github/workflows/render-email-action.yml` (explained in `docs/real-world-example.md`)

## Failure annotations

A non-zero build, validation or command exits with an `::error::` annotation. The annotation includes the first cause line from the command (for example `error TS2307: Cannot find module ...`), and the failure block reprints that cause plus the last 20 lines. The playbook's [troubleshooting table](docs/agent-playbook.md#when-something-goes-wrong) maps each message to a fix.

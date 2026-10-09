# AGENTS.md

Guidance for AI coding agents that work **in** this repository, or that **add this Action to another repository**.

## What this is

`LLazyEmail/email-template-workflows` is a GitHub **composite Action** (`action.yml` at the repo root, no compiled code). It:

1. Sets up Node.js (`actions/setup-node`).
2. Runs `npm install` in `working-directory`.
3. Renders email HTML, either by looping `npm run <build-script>` over input/output pairs, or by running a single shell `command`.
4. Writes `index.html` and `rendered.txt` into the artifact directory.
5. Uploads that directory as an artifact (`actions/upload-artifact`, 14-day retention).
6. On `pull_request`, creates or updates one bot comment headed `### Rendered emails`.

Current tag to use from other repos: `LLazyEmail/email-template-workflows@v1`.

## Adding the Action to another repository: decision rules

Follow in order and stop at the first match.

1. **Does the consumer have a CLI or script that renders a whole folder or catalog?** (for example `npx generate-template --all --out=generated`, `npm run sandbox`)
   Use **command mode**: set `command` and `artifact-directory`. Do not set `input`/`output`/`templates`; they are ignored.
2. **Does the consumer have an npm script that accepts `--input <path>` and `--output <path>`?**
   Use **script mode**.
   - One template: `input` + `output`.
   - Several in one job: `templates` (one `input:output` per line).
   - Many, with separate pass/fail per template: a job `matrix` with one `input`/`output`/`build-script` per row (see `examples/matrix-script-mode.yml`).
3. **The npm script does not accept those flags?** Use command mode with the exact command the project already uses, or change the script. Do not invent flags.

## Required caller setup

- Add `actions/checkout@v7` before the Action.
- Permissions on the caller job:
  - `contents: read`
  - `pull-requests: write` only if `pr-comment` is left at its default (`true`). Without it the comment step fails.
  - `packages: read` plus `GITHUB_TOKEN` in `env` if the consumer installs private GitHub Packages (for example `@llazyemail/*` via `.npmrc`).
- Set `working-directory` explicitly. The default is `generated`, which is rarely right. Use `.` when `package.json` is at the repo root.

## Input precedence and defaults

| Condition | Effect |
| --- | --- |
| `command` set | `templates`, `input`, `output`, `build-script`, `validate-script`, `extra-args` are all ignored. `artifact-directory` is **required** (the step exits 1 without it). |
| `templates` set | `input` and `output` are ignored. |
| neither | `input` and `output` are both required. |
| nothing renders | The step fails with "No templates rendered". |

Defaults worth knowing: `working-directory=generated`, `build-script=build-email`, `validate-script=validate-email`, `node-version=24`, `cache=""` (no cache), `upload-artifact=true`, `artifact-name=rendered-email`, `pr-comment=true`.

Outputs: `html-path` (first rendered file) and `html-count`.

## Gotchas (check these before reporting success)

- **`validate-script` runs by default** in script mode (`npm run validate-email -- --file <output>`). If the consumer has no such script, set `validate-script: ""` or the job fails.
- **`templates` lines split on the first `:`**. Paths containing a colon will break. Lines starting with `#` and blank lines are skipped. `input` and `output` must differ.
- **`input`/`output` are relative to `working-directory`**, and so is `artifact-directory`.
- **Command mode only indexes top-level `*.html` files** in `artifact-directory` (`find -maxdepth 1`), excluding `index.html`. Output in subfolders is uploaded but not listed in `index.html`.
- **Matrix jobs share one PR comment.** Every job posting would overwrite the same comment, so set `pr-comment: false` in matrix workflows and give each job a unique `artifact-name`.
- **`extra-args` is word-split by the shell**, not quoted. Do not put values with spaces in it.
- **`npm install`, not `npm ci`.** Do not assume a lockfile is enforced.
- **Pin `@v1`.** Do not use `@main`. Immutable patch tags (`v1.x.y`) exist when exact reproducibility is needed.
- **Known limitation:** issue #21 tracks Lit scripts that did not accept `--input`/`--output`. If a consumer's script does not accept them, use command mode.

## Verifying a change

After adding or editing a caller workflow:

1. Confirm the workflow YAML is valid and the `uses:` line is `LLazyEmail/email-template-workflows@v1`.
2. Confirm every `npm run` script named in `build-script` (and `validate-script`) exists in the consumer's `package.json`.
3. Confirm `artifact-directory` matches where the build actually writes.
4. Confirm permissions match the table above.
5. Push to a branch and open a pull request; the run should show an artifact named `artifact-name` and a single `### Rendered emails` comment.

## Working on this repository

- `action.yml` is the single source of truth. When inputs, defaults, or outputs change, update `README.md`, `llms.txt`, and this file in the same commit.
- `fixtures/consumer` and `.github/workflows/fixture-render.yml` exercise both modes via `uses: ./`. The `command` job sets `pr-comment: false` so a PR gets one comment, not two. Keep that.
- `renovate.json` manages dependency updates for the pinned `actions/*` versions.
- Do not add a build step or compiled code. The Action is composite YAML plus inline shell and `github-script`.
- Keep the comment markers in `action.yml` (`### Rendered emails` and the legacy headings) stable. The update-in-place behavior depends on them.

## Reference

- Inputs, outputs, defaults: `action.yml`
- Human-oriented docs: `README.md`
- Machine-oriented index: `llms.txt`
- Real consumer: `LLazyEmail/_playing_with_lit` → `.github/workflows/render-email-action.yml` (explained in `docs/real-world-example.md`)

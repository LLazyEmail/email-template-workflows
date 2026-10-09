# Real-world example: `_playing_with_lit`

This is how the Action is used in a real repository, `LLazyEmail/_playing_with_lit`.

Workflow file:
https://raw.githubusercontent.com/LLazyEmail/_playing_with_lit/refs/heads/main/.github/workflows/render-email-action.yml

## What the repository does

It holds 15 email templates, each rendered by its own npm script (`render:hackernoon`, `render:mailchimp`, `render:zurb`, and so on). The workflow renders all of them on every push to `main`, every pull request, and on manual dispatch. Each template is its own job so one failure does not hide the others.

This is **script mode inside a matrix**.

## Walkthrough

```yaml
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:
```
Runs on pushes to `main`, on pull requests, and on demand.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```
A newer push to the same ref cancels the older run.

```yaml
permissions:
  contents: read
  packages: read
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
`packages: read` and the `GITHUB_TOKEN` env var exist because the repository's `.npmrc` reads `GITHUB_TOKEN` to install private `@llazyemail/*` packages from GitHub Packages. There is no `pull-requests: write` because the comment is turned off (see below).

```yaml
strategy:
  fail-fast: false
  matrix:
    include:
      - template: hackernoon
        script: render:hackernoon
        input: src/scripts/hackernoon/render.ts
        output: generated/hackernoon-email.html
      # ...14 more rows
```
Each row names the template, the npm script that renders it, the script's source file (`input`) and the HTML file to write (`output`). `fail-fast: false` lets every row finish even if one fails.

```yaml
- uses: actions/checkout@v7
- uses: LLazyEmail/email-template-workflows@v1
  with:
    working-directory: .
    input: ${{ matrix.input }}
    output: ${{ matrix.output }}
    build-script: ${{ matrix.script }}
    validate-script: ""
    artifact-directory: generated
    artifact-name: action-rendered-${{ matrix.template }}
    pr-comment: false
```

| Input | Why it is set this way |
| --- | --- |
| `working-directory: .` | `package.json` is at the repository root. The default (`generated`) would be wrong. |
| `input` / `output` / `build-script` | Taken from the matrix row. The Action runs `npm run <script> -- --input <input> --output <output>`. |
| `validate-script: ""` | The repository has no `validate-email` script, and validation runs by default. |
| `artifact-directory: generated` | Where the HTML files are written. |
| `artifact-name: action-rendered-<template>` | Unique per job. Matrix jobs sharing one name would collide. |
| `pr-comment: false` | Fifteen jobs would otherwise overwrite the same pull request comment. |

## Notes

- The workflow's own header comment says the scripts accept `--input` but still render their registered sample payload, and that `--output` decides where the file is written.
- To get one pull request comment listing everything, use a single job with `templates:` or `command:` instead of a matrix. See `examples/script-mode-templates.yml` and `examples/command-mode.yml`.

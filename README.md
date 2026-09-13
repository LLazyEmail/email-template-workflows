# email-template-workflows

Reusable GitHub Action that installs a consumer repo's npm dependencies, runs an email render script, optionally validates the HTML, and can upload the result as an artifact.

This is **not** a drop-in copy of `_playing_with_lit` CI. That project uses `npm run render:template` / `render:hackernoon`. This action expects the **consumer** to expose npm scripts (defaults below).

## Usage

```yaml
name: Render email

on:
  push:
  pull_request:

jobs:
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: LLazyEmail/email-template-workflows@v1
        with:
          input: ./src/newsletter.md
          output: ./dist/newsletter.html
```

Pin a release tag (`@v1.0.1`) or a moving major (`@v1`) after that major tag is kept up to date. Do not pin `@main` in production workflows.

## Inputs

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `input` | yes | — | Path passed to the build script |
| `output` | yes | — | Path the build script should write |
| `build-script` | no | `build-email` | npm script name in the **consumer** `package.json` |
| `validate-script` | no | `validate-email` | npm script to run after build; empty skips |
| `node-version` | no | `24` | Installed when the setup-node PR is merged |
| `upload-artifact` | no | `true` | Set `false` if the caller uploads instead |

Exact input names depend on which follow-up PRs you merge. Until those land, only `input` and `output` exist and the action always runs `npm run build-email` / `validate-email`.

## Consumer contract

The action runs in the consumer checkout. You must provide:

- `package.json` with the configured scripts
- lockfile if you want npm cache hits
- the source file at `input`

Example `_playing_with_lit` mapping after configurable scripts land:

```yaml
- uses: LLazyEmail/email-template-workflows@v1
  with:
    input: .
    output: generated/nomoretogo-email.html
    build-script: render:template
    validate-script: ""
    upload-artifact: "true"
```

`render:template` in that repo does not take `--input` / `--output` today. Either add those flags to the scripts or change this action later to run `npm run <script>` with no extra args.

## Versioning

- Releases: https://github.com/LLazyEmail/email-template-workflows/releases
- Keep a moving `v1` tag on the latest compatible 1.x commit if you advertise `@v1`.
- Breaking input/script changes belong in `v2`.

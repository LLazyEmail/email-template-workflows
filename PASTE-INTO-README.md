<!-- Do NOT upload this file. Copy everything below the line into README.md,
     right after the intro paragraph ("Reusable GitHub Action that installs ..."). -->

---

## Quick start

Pick one render mode.

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

**Script mode**: you have an npm script that accepts `--input` and `--output`.

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: LLazyEmail/email-template-workflows@v1
    with:
      working-directory: .
      build-script: build-email
      input: src/welcome.md
      output: generated/welcome.html
```

## Real-world example

[`LLazyEmail/_playing_with_lit`](https://github.com/LLazyEmail/_playing_with_lit) renders 15 templates with a job matrix, one job per template: [`render-email-action.yml`](https://github.com/LLazyEmail/_playing_with_lit/blob/main/.github/workflows/render-email-action.yml). Line-by-line explanation: [docs/real-world-example.md](docs/real-world-example.md). More examples are in [`examples/`](examples/).

## For AI agents and LLM tools

- [`llms.txt`](llms.txt): short index of this repository for LLMs.
- [`AGENTS.md`](AGENTS.md): decision rules, input precedence, gotchas and a verification checklist for agents that add this Action to a repository.
- [`action.yml`](action.yml): source of truth for inputs, outputs and defaults.

---

## ALSO in README.md: add these rows to the Inputs table

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `install-command` | no | `npm install` | Command that installs dependencies in `working-directory`, for example `npm ci` |
| `retention-days` | no | `14` | Days to keep the uploaded artifact |

Also update these existing rows:

- `validate-script`: add "If the script is not defined in `package.json`, validation is skipped with a warning."
- `pr-comment`: add "Skipped for pull requests from forks."

## ALSO in README.md: replace the line "Outputs: `html-path` (first file) and `html-count`." with

Outputs: `html-path` (first file), `html-count`, `artifact-dir` (the uploaded directory) and `artifact-url` (link to the uploaded artifact, empty when `upload-artifact` is not `true`).

## ALSO in README.md: fix the stale sentence in "Consumer contract"

Remove "`_playing_with_lit` mapping is blocked on issue 21 unless it switches to `command`." That repository already uses script mode with `--input` and `--output`.

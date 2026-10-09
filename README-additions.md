<!-- Paste this block into README.md, e.g. right after the intro paragraph. -->

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
      validate-script: ""
```

## Real-world example

[`LLazyEmail/_playing_with_lit`](https://github.com/LLazyEmail/_playing_with_lit) renders 15 templates with a job matrix, one job per template: [`render-email-action.yml`](https://github.com/LLazyEmail/_playing_with_lit/blob/main/.github/workflows/render-email-action.yml). Line-by-line explanation: [docs/real-world-example.md](docs/real-world-example.md). More examples are in [`examples/`](examples/).

## For AI agents and LLM tools

- [`llms.txt`](llms.txt): short index of this repository for LLMs.
- [`AGENTS.md`](AGENTS.md): decision rules, input precedence, gotchas and a verification checklist for agents that add this Action to a repository.
- [`action.yml`](action.yml): source of truth for inputs, outputs and defaults.

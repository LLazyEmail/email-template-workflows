# email-template-workflows

Reusable GitHub Action that installs a consumer package, renders email HTML, uploads a browsable artifact, and on a pull request posts or updates one comment.

Pin `LLazyEmail/email-template-workflows@v1`. That floating major tag tracks the latest `v1.x` release. Immutable patch tags stay where they were published.

Two render modes:

- `templates` or `input` / `output` for a script that accepts `--input` and `--output`.
- `command` for a catalog engine. The action does not append flags. Set `artifact-directory` to the folder the command writes.

Lit scripts still do not accept `--input` / `--output`. That mismatch is tracked in https://github.com/LLazyEmail/email-template-workflows/issues/21. Use `command` for those until the scripts grow the flags.

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

## Usage

The caller job needs `pull-requests: write` or the comment step fails. Set `pr-comment: false` to skip it.

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

Single template and `templates:` lines still work. The package version is the consumer `package.json` dependency. The artifact is a directory; the comment links the run and tells you to open `index.html`.

The comment heading is `### Rendered emails`. A later run updates the existing bot comment instead of adding another one. It also replaces an older `### Sandbox HTML` or fixture comment.

## Inputs

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `command` | no | empty | Shell command after install. Ignores `templates`, `input`, `output`, `build-script`, and `validate-script`. |
| `templates` | no | empty | Multiline `input:output` pairs. Ignored when `command` is set. |
| `input` | no | empty | Single source path, relative to `working-directory` |
| `output` | no | empty | Single HTML path, relative to `working-directory` |
| `working-directory` | no | `generated` | Directory that contains `package.json` |
| `build-script` | no | `build-email` | npm script in that package |
| `validate-script` | no | `validate-email` | Empty skips validation |
| `extra-args` | no | empty | Appended after `--input` and `--output` for every template |
| `node-version` | no | `24` | Node.js version |
| `cache` | no | empty | `npm`, `yarn`, or `pnpm`. Empty skips cache |
| `upload-artifact` | no | `true` | Upload the HTML directory |
| `artifact-name` | no | `rendered-email` | Artifact name |
| `artifact-directory` | no | empty | Directory to index and upload. Required when `command` is set. |
| `pr-comment` | no | `true` | Post or update the pull request comment. No-op unless the event is `pull_request`. |

Set `command`, or `templates`, or both `input` and `output`. The action writes `index.html` and `rendered.txt` into the artifact directory and uploads that directory.

Outputs: `html-path` (first file) and `html-count`.

## Fixture

`fixtures/consumer` covers both modes. The `render` job lets the action comment. The `command` job sets `pr-comment: false` so a pull request gets one comment, not two. `.github/workflows/fixture-render.yml` calls `uses: ./`.

## Consumer contract

The action runs `npm install` inside `working-directory`. Without `command`, it then runs `npm run <build-script> -- --input ... --output ... <extra-args>` for each template. With `command`, it runs that shell command and indexes `artifact-directory`.

`_playing_with_lit` mapping is blocked on issue 21 unless it switches to `command`.

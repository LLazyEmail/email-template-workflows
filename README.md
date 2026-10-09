# email-template-workflows

Reusable GitHub Action that installs a consumer package, runs an email render script, optionally validates the HTML, and can upload the result as an artifact.

This is not a drop-in copy of `_playing_with_lit` CI. That mismatch is tracked in https://github.com/LLazyEmail/email-template-workflows/issues/21. Lit scripts still do not accept `--input` / `--output`.

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
      - uses: actions/checkout@v7
      - uses: LLazyEmail/email-template-workflows@v1
        with:
          working-directory: generated
          input: ../src/newsletter.md
          output: newsletter.html
          extra-args: ""
          cache: npm
```

`@v1` still points at the September 2026 release. Do not pin it until `v1` is moved. Use the branch or a new tag after the fixture workflow is green.

## Inputs

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `input` | yes | — | Source path, relative to `working-directory` |
| `output` | yes | — | HTML path, relative to `working-directory` |
| `working-directory` | no | `generated` | Directory that contains `package.json` |
| `build-script` | no | `build-email` | npm script in that package |
| `validate-script` | no | `validate-email` | Empty skips validation |
| `extra-args` | no | empty | Appended after `--input` and `--output` |
| `node-version` | no | `24` | Node.js version |
| `cache` | no | empty | `npm`, `yarn`, or `pnpm`. Empty skips cache |
| `upload-artifact` | no | `true` | Upload the HTML (with index.html) |
| `artifact-name` | no | `rendered-email` | Artifact name |

`html-path` is `${working-directory}/${output}` relative to the workspace.

When `upload-artifact` is true, the action writes a simple `index.html` next to the rendered HTML and uploads the directory as an artifact. Download the artifact and open `index.html` for a browsable list of the generated emails.

## Fixture

`fixtures/consumer` is a package whose `build-email` script accepts `--input`, `--output`, and an optional `--title` extra arg. `.github/workflows/fixture-render.yml` calls `uses: ./` so the action is tested without a release tag.

On pull requests the fixture workflow also posts a comment with a link to the run and instructions for opening the artifact.

## Consumer contract

The action runs `npm install` and `npm run <build-script> -- --input ... --output ... <extra-args>` inside `working-directory`. The default directory is `generated`, which is where this project writes HTML. If `package.json` lives at the repo root, set `working-directory: .`.

`_playing_with_lit` mapping is blocked on issue 21.

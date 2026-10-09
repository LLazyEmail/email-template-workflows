# email-template-workflows

Reusable GitHub Action that installs a consumer package, runs an email render script for one or more templates, optionally validates the HTML, and uploads a browsable artifact.

Pin `LLazyEmail/email-template-workflows@v1`. That floating major tag tracks the latest `v1.x` release. Immutable patch tags (`v1.0.1`, `v1.1.1`, `v1.2.0`) stay where they were published.

This is not a drop-in copy of `_playing_with_lit` CI. That mismatch is tracked in https://github.com/LLazyEmail/email-template-workflows/issues/21. Lit scripts still do not accept `--input` / `--output`.

## Usage

Single template:

```yaml
- uses: LLazyEmail/email-template-workflows@v1
  with:
    working-directory: generated
    input: ../src/newsletter.md
    output: newsletter.html
```

Several templates (one `input:output` pair per line):

```yaml
- uses: LLazyEmail/email-template-workflows@v1
  with:
    working-directory: generated
    templates: |
      ../src/newsletter.md:newsletter.html
      ../src/welcome.md:welcome.html
    artifact-directory: .
    upload-artifact: true
    artifact-name: rendered-email
```

The artifact is a directory, not a single file. Download it and open `index.html`.

## Inputs

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `templates` | no | empty | Multiline `input:output` pairs. When set, `input` and `output` are ignored. |
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
| `artifact-directory` | no | empty | Directory to index and upload. Empty uses the directory of the first output. |

Set `templates`, or both `input` and `output`. The action writes `index.html` and `rendered.txt` into the artifact directory and uploads that directory.

Outputs: `html-path` (first file) and `html-count`.

## Fixture

`fixtures/consumer` renders `src/newsletter.md` and `src/welcome.md` into `generated/`. `.github/workflows/fixture-render.yml` calls `uses: ./` so the action is tested without a release tag.

On pull requests that workflow posts or updates a comment listing every rendered file, with a link to the run and instructions to open `index.html` from the `fixture-email` artifact. `example-workflow.yml` shows the same comment pattern for consumers.

## Consumer contract

The action runs `npm install` and, for each template, `npm run <build-script> -- --input ... --output ... <extra-args>` inside `working-directory`. The default directory is `generated`. If `package.json` lives at the repo root, set `working-directory: .`.

`_playing_with_lit` mapping is blocked on issue 21.

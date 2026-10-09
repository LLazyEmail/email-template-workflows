# email-template-workflows

Reusable GitHub Action that installs a consumer package, renders email HTML, and uploads a browsable artifact.

Pin `LLazyEmail/email-template-workflows@v1`. That floating major tag tracks the latest `v1.x` release. Immutable patch tags stay where they were published.

Two render modes:

- `templates` or `input` / `output` for a script that accepts `--input` and `--output`.
- `command` for a catalog engine. The action does not append flags. Set `artifact-directory` to the folder the command writes.

Lit scripts still do not accept `--input` / `--output`. That mismatch is tracked in https://github.com/LLazyEmail/email-template-workflows/issues/21. Use `command` for those until the scripts grow the flags.

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

Catalog engine, including `@llazyemail/generate-template`:

```yaml
- uses: LLazyEmail/email-template-workflows@v1
  with:
    working-directory: .
    command: npx generate-template --all --out=generated
    artifact-directory: generated
    artifact-name: rendered-email
```

The package version is the consumer `package.json` dependency, not an action input. Bump `@llazyemail/generate-template` there; this workflow renders whatever is installed. The artifact is a directory. Download it and open `index.html`.

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

Set `command`, or `templates`, or both `input` and `output`. The action writes `index.html` and `rendered.txt` into the artifact directory and uploads that directory.

Outputs: `html-path` (first file) and `html-count`.

## Fixture

`fixtures/consumer` covers both modes. The `render` job passes two `templates` lines. The `command` job runs `npm run render-all` and indexes `generated/`. `.github/workflows/fixture-render.yml` calls `uses: ./` so the action is tested without a release tag.

On pull requests the templates job posts or updates a comment listing every rendered file.

## Consumer contract

The action runs `npm install` inside `working-directory`. Without `command`, it then runs `npm run <build-script> -- --input ... --output ... <extra-args>` for each template. With `command`, it runs that shell command and indexes `artifact-directory`.

`_playing_with_lit` mapping is blocked on issue 21 unless it switches to `command`.

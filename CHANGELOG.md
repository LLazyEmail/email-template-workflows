# Changelog

All notable changes to `LLazyEmail/email-template-workflows` are listed here.

## [Unreleased]

### Added
- `install-command` input (default `npm install`) so consumers can use `npm ci` or another installer.
- `retention-days` input (default `14`) for the uploaded artifact.
- `artifact-dir` and `artifact-url` outputs.
- The pull request comment links directly to the uploaded artifact.
- Hidden marker `<!-- email-template-workflows -->` in the pull request comment, used to find it again.
- `AGENTS.md`, `llms.txt`, `CLAUDE.md` and `.github/copilot-instructions.md` for AI agents and LLM tools.
- `examples/` with script, templates, command and matrix workflows, and `docs/real-world-example.md`.
- `.github/workflows/release.yml`, which moves the floating major tag (for example `v1`) when a release is published.

### Changed
- `validate-script` is now skipped with a warning when the script is not defined in `package.json`. It used to fail the job.
- Command mode indexes `*.html` files at any depth, and `index.html` links use paths relative to `artifact-directory`. File names are HTML-escaped.
- `cache-dependency-path` follows the `cache` input (`package-lock.json`, `yarn.lock` or `pnpm-lock.yaml`).
- The comment step is skipped for pull requests from forks, which only get a read-only token.
- The comment step reads all pages of existing comments, and prefers the hidden marker over the legacy headings.

### Fixed
- A duplicate comment could be posted on pull requests with more than 30 comments.
- yarn and pnpm caching looked for `package-lock.json`.

### Removed
- `example-workflow.yml` at the repository root. It posted its own comment on top of the built-in one. Use `examples/` instead.

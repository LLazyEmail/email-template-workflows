# Copilot instructions

Read `AGENTS.md` at the repository root before changing anything. It is the full guide.

Short version:

- This repository is one GitHub composite Action (`action.yml`) backed by shell scripts in `scripts/` and tests in `tests/`. There is no compiled code and no build step.
- `action.yml` is the source of truth for inputs, outputs and defaults. When it changes, update `README.md`, `llms.txt`, `AGENTS.md` and `CHANGELOG.md` in the same commit.
- Run `bash tests/render.test.sh`, `bash tests/detect-package-manager.test.sh`, `node tests/pr-comment.test.js` and `python3 tests/check-action.py` before committing. Keep shell compatible with bash 3.2 and Git Bash.
- Pin every `uses:` to a full commit SHA with a version comment.
- Keep the pull request comment markers stable: the hidden `<!-- email-template-workflows -->` marker and the `### Rendered emails` heading.
- Consumers pin `LLazyEmail/email-template-workflows@v1`, never `@main`.
- `fixtures/consumer` and `.github/workflows/fixture-render.yml` test the Action with `uses: ./`.

# Copilot instructions

Read `AGENTS.md` at the repository root before changing anything. It is the full guide.

Short version:

- This repository is one GitHub composite Action (`action.yml`). There is no compiled code and no build step.
- `action.yml` is the source of truth for inputs, outputs and defaults. When it changes, update `README.md`, `llms.txt`, `AGENTS.md` and `CHANGELOG.md` in the same commit.
- Keep the pull request comment markers stable: the hidden `<!-- email-template-workflows -->` marker and the `### Rendered emails` heading.
- Consumers pin `LLazyEmail/email-template-workflows@v1`, never `@main`.
- `fixtures/consumer` and `.github/workflows/fixture-render.yml` test the Action with `uses: ./`.

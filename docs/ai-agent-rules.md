# Strict AI agent rules

Rules that keep AI coding agents shipping reliable, reviewable, top-level software in this repository.

Follow these on every change. Prefer the smallest correct change that passes all checks.

## 1. Never invent

- Do not invent inputs, scripts, flags, paths, package managers, or file patterns.
- Read `action.yml`, `README.md`, and the relevant script before proposing anything.
- If a behaviour is unclear, add a test that documents the real behaviour instead of guessing.

## 2. One concern per PR

- One logical change per pull request.
- Open as draft first.
- Title must say what the change does, not just the branch name.
- Description must list the user-facing effect and the test that covers it.

## 3. Tests are mandatory

Every behaviour change must update or add a test in the same PR:

- `tests/render.test.sh` for render logic, indexing, size warnings, escaping.
- `tests/detect-package-manager.test.sh` for package-manager detection.
- `tests/pr-comment.test.js` for comment formatting.
- `tests/check-action.py` for documentation and expression consistency.
- `tests/changelog-entries.test.sh` when changelog machinery changes.

A PR that changes behaviour without a test is incomplete.

## 4. Backward compatibility is the default

- New inputs and outputs must have defaults that leave existing users unchanged.
- Do not rename or remove existing inputs or outputs. Add aliases instead.
- Do not change default warning titles or annotation formats that tests already assert on.
- Document the new surface in the README inputs/outputs tables in the same commit.

## 5. Shell constraints

- Compatible with bash 3.2 (macOS) and Git Bash (Windows).
- No `mapfile`, no namerefs, no bare expansion of a possibly empty array under `set -u`.
- Functions called from `if` must end failing commands with `|| return 1`.
- Prefer `node` one-liners for path and escaping work that must be portable.

## 6. Documentation stays in sync

When `action.yml` changes:

- Update the README inputs and outputs tables.
- Update `AGENTS.md` and `llms.txt` if the decision rules or defaults change.
- Add a `.changelog/` entry (do not hand-edit `CHANGELOG.md`).
- `python3 tests/check-action.py` must pass.

## 7. CI must be green before review

Do not request review while any required check is red.

Required checks:

- `python3 tests/check-action.py`
- `bash tests/render.test.sh`
- `bash tests/detect-package-manager.test.sh`
- `node tests/pr-comment.test.js`
- `bash tests/changelog-entries.test.sh`
- yamllint, shellcheck, actionlint (via CI)

If a test fails, fix the code or the test in the same branch before asking for review.

## 8. Error messages stay useful

- Failures must produce an `::error::` annotation that names the failing template or command.
- Include the first useful cause line from the tool (tsc, missing module, etc.).
- Do not swallow errors or replace them with generic messages.

## 9. No compiled code

The Action stays composite YAML + shell + one `github-script` file. Do not add a build step, TypeScript compilation, or a package that must be published.

## 10. Pinning and security

- Every third-party `uses:` is a full commit SHA with a `# vX.Y.Z` comment.
- Do not replace a SHA with a floating tag.
- Minimal permissions on every job.

## 11. When in doubt

- Prefer the change that existing users will not notice.
- Prefer the change that a future agent can understand from the README and the test.
- Prefer deleting complexity over adding a new flag.

## Quick checklist for an agent

- [ ] Read `action.yml` and the relevant script first.
- [ ] One concern, draft PR.
- [ ] Test added or updated.
- [ ] README table updated if inputs/outputs changed.
- [ ] `.changelog/` entry added for user-facing changes.
- [ ] `python3 tests/check-action.py` and the relevant unit tests pass locally.
- [ ] CI green before requesting review.

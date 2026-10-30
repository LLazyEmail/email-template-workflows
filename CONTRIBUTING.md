# Contributing to email-template-workflows

Thanks for helping maintain the reusable email-template render Action.

## Guidelines

1. **Small, single-purpose draft PRs.** One concern per PR; open as draft first.
2. **Never delete curated docs content**; extend or annotate instead.
3. **Pin third-party Actions** to a full commit SHA with a `# vX.Y.Z` comment.
4. **`action.yml` is the source of truth.** When inputs, defaults, or outputs
   change, update `README.md`, `llms.txt`, `AGENTS.md`, and add a `.changelog/`
   entry in the same PR (do not hand-edit `CHANGELOG.md` for those changes).
5. **Add a unit test** with every behaviour change
   (`tests/detect-package-manager.test.sh`, `tests/render.test.sh`,
   `tests/pr-comment.test.js`, or `tests/check-action.py` as appropriate).
6. Keep shell compatible with bash 3.2 (macOS) and Git Bash (Windows).

## Commit trailer

When working for the maintainer, every commit carries:

```
Co-authored-by: petroved <arthur.tkachenko.netweight@gmail.com>
```

## Local checks

```bash
pipx run 'yamllint==1.38.0' --format github .
# after actionlint is installed:
actionlint
bash tests/detect-package-manager.test.sh
bash tests/render.test.sh
node tests/pr-comment.test.js
python3 tests/check-action.py
bash tests/changelog-entries.test.sh
bash scripts/changelog-check.sh
```

## Changelog entries

For every user-facing change, add **one** markdown file under `.changelog/`
instead of editing `CHANGELOG.md` directly:

```bash
slug=$(git branch --show-current | tr '/' '-')
cat > ".changelog/${slug}.md" <<'ENTRY'
semver: minor
type: Added
Short user-facing summary of the change.
ENTRY
```

Rules:

1. Required header: `semver: major|minor|patch`.
2. Optional header: `type: Added|Changed|Deprecated|Removed|Fixed|Security`.
3. Body is the Keep a Changelog bullet (multi-line OK).
4. Docs-only / chore PRs that should not affect the next version: add the
   `skip-changelog` or `no-changelog` label.
5. Local check: `bash scripts/changelog-check.sh`.

Full format notes: [`.changelog/README.md`](.changelog/README.md). After entries
merge to `main`, the Changelog release PR workflow proposes the version bump;
publishing the GitHub Release still moves the floating major tag via
`release.yml` (`v1`, `v2`, …).

## License

By contributing, you agree your contributions are licensed under the MIT License.

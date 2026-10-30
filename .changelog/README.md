# Changelog entries

Every user-visible change to `email-template-workflows` gets **one file** in this
directory. Feature branches are short-lived, so a change needs exactly one file
to record what it did and how far it moves the version.

```
.changelog/short-slug.md
```

The filename is a short slug — it only exists so two PRs never collide. The
file contents become the changelog line(s).

```markdown
semver: minor
Added a `zip-artifact` input that packs the rendered directory before upload.
```

## Choosing the bump and the category

The file starts with a small header:

```
semver: {major|minor|patch}
type: {Added|Changed|Deprecated|Removed|Fixed|Security}
```

`semver:` is **required** — it says whether your change is breaking (`major`),
a backwards-compatible addition (`minor`), or a fix (`patch`). There is no
default; leaving it out fails CI rather than guessing how far the version
should move.

`type:` is optional. It picks the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
heading your entry appears under. Without it the category follows the bump:
`major → Changed`, `minor → Added`, `patch → Fixed`.

```markdown
semver: patch
type: Security
Pinned a third-party Action to a full commit SHA after a CVE notice.
```

The two header lines can be in either order. The header ends at the first line
that is not one of them.

## Longer entries

Extra lines are indented under the bullet. If you write your own `- ` bullets,
they pass through untouched.

## What happens next

1. On every pull request, CI validates that an entry exists and the header is
   well-formed (waive with the `skip-changelog` or `no-changelog` label when the
   PR is docs-only / chore-only).
2. After entries land on `main`, the **Changelog release PR** workflow opens
   (or refreshes) a `chore(release): vX.Y.Z` pull request that folds waiting
   entries into `CHANGELOG.md` and deletes the consumed files. The highest
   `semver:` among waiting entries wins. Existing hand-edited history in
   `CHANGELOG.md` is kept; new sections are appended above it.
3. Merge that release PR, then publish a GitHub Release with tag
   `vMAJOR.MINOR.PATCH`. Existing `.github/workflows/release.yml` moves the
   floating major tag (`v1`, `v2`, …) — unchanged by this workflow.

## Adding an entry (quick)

```bash
slug=$(git branch --show-current | tr '/' '-')
cat > ".changelog/${slug}.md" <<'ENTRY'
semver: minor
type: Added
Short user-facing summary of the change.
ENTRY
```

Then mention the new file in the PR.

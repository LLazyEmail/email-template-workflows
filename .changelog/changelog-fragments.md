semver: minor
type: Added
`.changelog/` fragment workflow: per-PR entry files with required `semver:`
(+ optional `type:`), `scripts/changelog-check.sh` and a unit test, PR
validation workflow, and a post-merge release-PR workflow
(`dottics/actions-changelog@v2.0.2`, SHA-pinned) that compiles waiting entries
into `CHANGELOG.md`. Existing hand-edited changelog history and the floating
major-tag `release.yml` stay in place.

semver: minor
type: Added
Auto-publish on merge: after a release PR lands, create the vX.Y.Z tag and GitHub Release from CHANGELOG.md, and move the floating major tag (v2). Ports documentation-actions #27 plus the GITHUB_TOKEN major-tag fix. Idempotent so a missed release (for example v2.4.0 already on CHANGELOG) is published on the first run when the tag is still missing.

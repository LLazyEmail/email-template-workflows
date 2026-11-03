# Keeping consumers up to date

How repositories that call `LLazyEmail/email-template-workflows` should receive
version bumps **without a cross-repo token**.

## Why there is no cross-repo cascade

An earlier approach (`.github/workflows/cascade-bumps.yml`) tried to open update
pull requests in every consumer from this repository. That path needs a
repository or org secret (`CASCADE_TOKEN`) with **Contents** and **Pull
requests** write on each target. The default `GITHUB_TOKEN` cannot create
branches or pull requests in other repositories, so the cascade failed whenever
the secret was missing (see [#32](https://github.com/LLazyEmail/email-template-workflows/issues/32)).

The supported model is the opposite direction:

1. Each consumer pins this Action in its own `.github/workflows/*.yml`.
2. That consumer’s **own** dependency bot (Renovate or Dependabot) opens an
   update PR using that repository’s token.
3. Humans review CI on the consumer PR and merge when ready.

No secret is shared across repositories. Adding a new consumer never requires
updating a central workflow or granting a PAT wider access.

## Current LLazyEmail consumers

These repositories call the Action today (all on Renovate; pins use `@v3`):

| Repository | Workflow | Pin |
| --- | --- | --- |
| [`LLazyEmail/render-template`](https://github.com/LLazyEmail/render-template) | `.github/workflows/sandbox.yml` | `@v3` |
| [`LLazyEmail/generate-template`](https://github.com/LLazyEmail/generate-template) | `.github/workflows/sandbox.yml` | `@v3` |
| [`LLazyEmail/template-runtime-display`](https://github.com/LLazyEmail/template-runtime-display) | `.github/workflows/generate.yml` | `@v3` |
| [`LLazyEmail/postmark-transactional-template-simple`](https://github.com/LLazyEmail/postmark-transactional-template-simple) | `.github/workflows/generate-templates.yml` | `@v3` |
| [`LLazyEmail/_playing_with_lit`](https://github.com/LLazyEmail/_playing_with_lit) | `.github/workflows/render-email-action.yml` | `@v3` |

When you add another consumer, configure Renovate or Dependabot there (copy a
snippet below) and optionally add a row to this table in a docs PR.

## Pin formats the bots understand

Prefer one of these in workflow YAML:

```yaml
# Floating major (tracks latest v3.x once the major tag moves)
- uses: LLazyEmail/email-template-workflows@v3

# Exact release
- uses: LLazyEmail/email-template-workflows@v3.0.0

# Immutable digest with a version comment (strongest supply-chain pin)
- uses: LLazyEmail/email-template-workflows@<full-commit-sha> # v3.0.0
```

Notes:

- Renovate’s `helpers:pinGitHubActionDigestsToSemver` (used by several LLazyEmail
  repos) may rewrite `@v3` / `@v3.0.0` into a digest + version comment. That is
  intentional and still updates when a newer `v3.x.y` ships.
- Dependabot understands the same three forms for `package-ecosystem:
  github-actions`.
- Do **not** pin `@main` in production consumers. Use a release tag or a digest.

## How major and minor tags work

This repository publishes:

| Tag | Meaning |
| --- | --- |
| `v3.0.0`, `v3.1.0`, … | Immutable release tags (and matching GitHub Releases). |
| `v3` | Floating major tag. After each `v3.x.y` release, `release.yml` moves `v3` to that commit. |
| `v2`, `v2.7.1`, … | Previous major line; still available if you need the old defaults. |

Choosing a pin:

- **`@v3`** — get patch/minor moves automatically when the floating tag updates
  (or via digest bumps if Renovate pins digests). Breaking changes stay on the
  next major (`@v4`).
- **`@v3.x.y`** — stay on one release until a bot or human opens a bump PR.
- **`@v2`** — keep the email-oriented v2 defaults (`product-name: emails`,
  `size-limit-kb: 102`, `artifact-name: rendered-email`).

## Handling breaking majors

When a new major is cut (for example v3 after v2):

1. Read [`CHANGELOG.md`](../CHANGELOG.md) and the upgrade section in the
   [`README`](../README.md#upgrading-from-v2).
2. Apply migration in the **same** consumer PR that bumps the pin (rename
   `EMAIL_TEMPLATE_*` → `FILE_*` in new commands, set explicit
   `product-name` / `size-limit-kb` / `artifact-name` if you still want the old
   email defaults).
3. Keep majors **manual** in Renovate/Dependabot (no automerge) so CI and the
   migration are reviewed together.
4. After merge, optionally update the consumer row in this document.

Minor and patch releases should not need workflow edits beyond the pin bump.

## Copy-paste: Renovate

If the repository already has a Dependency Dashboard or `renovate.json`, **extend
that config** — do not add Dependabot beside it for the same ecosystem.

Add a dedicated `packageRules` entry so this Action gets its own PR group and
the `dependencies` label (create the label once if it is missing):

```json
{
  "description": "Group LLazyEmail/email-template-workflows Action updates",
  "matchManagers": ["github-actions"],
  "matchPackageNames": [
    "LLazyEmail/email-template-workflows",
    "llazyemail/email-template-workflows"
  ],
  "groupName": "email-template-workflows",
  "labels": ["dependencies"],
  "commitMessageTopic": "email-template-workflows"
}
```

Place it **after** any broad `matchManagers: ["github-actions"]` grouping rule
so this `groupName` wins for this package. Keep a separate rule with
`"matchUpdateTypes": ["major"], "automerge": false` so majors stay manual.

Minimal starter `renovate.json` if the repo has none:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    "helpers:pinGitHubActionDigestsToSemver",
    "schedule:weekly"
  ],
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "matchPackageNames": ["LLazyEmail/email-template-workflows"],
      "groupName": "email-template-workflows",
      "labels": ["dependencies"]
    },
    {
      "matchUpdateTypes": ["major"],
      "automerge": false
    }
  ]
}
```

## Copy-paste: Dependabot

Use Dependabot only when Renovate is **not** already running. Fighting both
bots on `github-actions` creates duplicate PRs.

`.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
      day: monday
      time: "05:00"
      timezone: Europe/Kyiv
    labels:
      - dependencies
    groups:
      email-template-workflows:
        patterns:
          - LLazyEmail/email-template-workflows
    # Majors: leave ungrouped or review carefully; Dependabot opens one PR per bump.
    open-pull-requests-limit: 10
```

Daily schedule variant: set `interval: daily` instead of `weekly`.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| No bump PRs after a release | Bot not installed / schedule not due / pin is floating `@v3` without digest pinning | Check the Dependency Dashboard (Renovate) or Dependabot alerts; wait for schedule; or pin `@v3.x.y` / a digest so in-major bumps are visible |
| Cascade / `CASCADE_TOKEN` errors | Old cross-repo workflow | That workflow is removed. Configure Renovate or Dependabot on the consumer instead |
| Renovate PR missing `dependencies` label | Label absent or rule not matching | Create the label; confirm `matchPackageNames` includes `LLazyEmail/email-template-workflows` |
| Two bots open the same bump | Renovate and Dependabot both watch `github-actions` | Disable one ecosystem on one bot |
| Major bump CI fails | Breaking defaults (v2 → v3) | Follow [Upgrading from v2](../README.md#upgrading-from-v2); set `product-name`, `size-limit-kb`, `artifact-name`, prefer `$FILE_*` |
| Digest pin looks scary | Renovate pinned the Action SHA | Keep the `# vX.Y.Z` comment; Renovate will move the digest on the next release |

## FAQ

**Why not keep cascade-bumps.yml behind a documented secret?**  
Org-wide write tokens are easy to leave unset, expire, or over-scope. Consumer-side
bots already have the right token boundary and scale when new repos appear.

**Does `@v3` mean I never see PRs for 3.0.1?**  
If you leave a floating major and do not pin digests, GitHub resolves `@v3` to
the latest moving tag at runtime — you may get patch/minor code without a PR.
Digest pinning (or an exact `@v3.x.y`) makes every bump a reviewable PR.

**Can this Action’s own `renovate.json` update consumers?**  
No. Renovate in *this* repository only updates dependencies *of* this
repository. Each consumer must run its own bot.

**What about `generate-template`’s cascade workflow?**  
That workflow bumps the **npm** package `@llazyemail/generate-template` in
downstream package.json files. It is unrelated to this Action’s GitHub Actions
pins and is unchanged by removing `CASCADE_TOKEN` here.

**How do I stop automerging a mistaken Action major?**  
Ensure a Renovate rule sets `"matchUpdateTypes": ["major"], "automerge": false`
(as in the LLazyEmail consumer configs). For Dependabot, do not enable
auto-merge on major updates.

**Where are release notes?**  
[`CHANGELOG.md`](../CHANGELOG.md). New notes are assembled from
[`.changelog/`](../.changelog/) fragments on release PRs.

## Removed: cascade-bumps + CASCADE_TOKEN

The workflow `.github/workflows/cascade-bumps.yml` and `docs/cascade-bumps.md`
are removed. Do not add `CASCADE_TOKEN` for this repository’s Action bumps.
Use the Renovate or Dependabot snippets above on each consumer instead.

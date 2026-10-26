# Cascade action bumps

After a release of `LLazyEmail/email-template-workflows` you can open update pull requests in the other LLazyEmail repositories with one workflow.

This repository publishes a **GitHub Action**, not an npm package. Consumers pin it in their workflow files:

```yaml
- uses: LLazyEmail/email-template-workflows@v2.1.0
```

(or the floating major `@v1` / `@v2`).

## How to run

1. Go to **Actions → Cascade action bumps → Run workflow**.
2. Enter the version that was just released (e.g. `v2.2.0` or `2.2.0`).
3. Leave `repos` empty to use the default list, or override it.
4. Check `dry_run` first if you want to preview the changes.
5. Leave `update_floating` unchecked unless you also want to turn `@v1` / `@v2` into the exact new tag.

Default targets (repos known to pin a specific version):

- `LLazyEmail/generate-template`
- `LLazyEmail/postmark-transactional-template-simple`
- `LLazyEmail/_playing_with_lit`
- `LLazyEmail/template-runtime-display`
- `LLazyEmail/render-template`

## Required secret

Add an organization or repository secret named **`CASCADE_TOKEN`**:

- Fine-grained personal access token **or** a GitHub App installation token.
- Permissions needed on every consumer repository:
  - Contents: Read and write
  - Pull requests: Read and write
- (Recommended) Restrict the token to only the repositories that should receive bumps.

The default `GITHUB_TOKEN` cannot create branches or pull requests in other repositories.

## What the workflow does

For each target repository it:

1. Checks out `main`.
2. Finds `.github/workflows/*.yml` files that contain `LLazyEmail/email-template-workflows@`.
3. Replaces exact version pins (`@v1.2.3`) with the new tag.
4. By default leaves floating majors (`@v1`, `@v2`) alone.
5. Opens a pull request on branch `chore/bump-email-template-workflows-<tag>` labeled `dependencies`.

## Adding a new consumer

1. Make sure the repository has at least one workflow that uses the action.
2. Add it to the default list inside `.github/workflows/cascade-bumps.yml` **or** pass it in the `repos` input.
3. Ensure `CASCADE_TOKEN` has write access to that repository.

## Safety notes

- The workflow is `workflow_dispatch` / `workflow_call` only — it never runs automatically on release.
- Use `dry_run` first.
- Floating major tags stay floating unless you explicitly set `update_floating`.
- Review the opened PRs and their CI before merging.

---

See also the matching cascade in [generate-template](https://github.com/LLazyEmail/generate-template/blob/main/.github/workflows/cascade-bumps.yml).

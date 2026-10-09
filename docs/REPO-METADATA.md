# Repository metadata suggestions

The repository currently shows "No description, website, or topics provided." Search engines, GitHub search, the Marketplace and AI agents all use these fields. They are set in the GitHub UI, not in a file, so this page lists what to paste.

## Description (About box)

> GitHub Action that renders email templates to HTML in CI, uploads a browsable artifact, and posts one updating "Rendered emails" comment on pull requests.

## Website

https://github.com/marketplace/actions/render-email-template

## Topics

`github-action` `github-actions` `email` `email-template` `html-email` `mjml` `lit` `markdown` `ci` `preview` `composite-action` `workflow` `pull-request`

## Marketplace branding (optional, in `action.yml`)

```yaml
branding:
  icon: mail
  color: blue
```

## Release hygiene

- Publish releases (the Releases section is empty today) and keep the floating `v1` tag moved to the latest `v1.x`.
- Mention `llms.txt` and `AGENTS.md` in the README so people and agents find them.

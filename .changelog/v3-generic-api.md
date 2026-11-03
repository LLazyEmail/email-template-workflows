semver: major
type: Changed
Generic public API: action name is now Render Static Artifacts; defaults are product-name=files, size-limit-kb=0, artifact-name=rendered. Builds receive FILE_INPUT and FILE_OUTPUT (EMAIL_TEMPLATE_* still set for compatibility). html-path and html-count remain as aliases of file-path and file-count. Pin @v2 to keep the old defaults.

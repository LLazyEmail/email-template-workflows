#!/usr/bin/env python3
"""Static checks for action.yml and the workflows in this repository.

Needs PyYAML (pip install pyyaml). Run from the repository root:

    python3 tests/check-action.py

Checks:
  * action.yml is a composite action and every run step sets `shell`
  * every input has a description and an explicit default
  * every `inputs.*` and `steps.*.outputs.*` expression refers to something defined
  * every input and output is documented in README.md
  * every environment variable that scripts/render.sh and the other scripts read
    from the environment is provided by action.yml
  * every third-party `uses:` is pinned to a full commit SHA
  * every ```yaml block in the docs parses, and every call to this Action in the
    docs and in examples/ uses only inputs that exist in action.yml, pinned to @v1
  * relative links and #anchors in the docs point at files and headings that exist
"""
import glob
import os
import re
import sys

import yaml

errors = []


def error(message):
    errors.append(message)
    print(f"  FAIL {message}")


def ok(message):
    print(f"  ok   {message}")


with open("action.yml", encoding="utf-8") as handle:
    raw = handle.read()
action = yaml.safe_load(raw)

print("action.yml")
inputs = action.get("inputs", {})
outputs = action.get("outputs", {})
steps = action["runs"]["steps"]

if action["runs"].get("using") == "composite":
    ok("is a composite action")
else:
    error("runs.using must be composite")

missing_shell = [s.get("name", s.get("id", "?")) for s in steps if "run" in s and "shell" not in s]
if missing_shell:
    error(f"run steps without shell: {missing_shell}")
else:
    ok("every run step sets shell")

for name, spec in inputs.items():
    if not spec.get("description"):
        error(f"input '{name}' has no description")
    if "default" not in spec:
        error(f"input '{name}' has no explicit default")
ok(f"{len(inputs)} inputs checked for description and default")

step_ids = {s["id"] for s in steps if "id" in s}
for ref in sorted(set(re.findall(r"inputs\.([A-Za-z0-9_-]+)", raw))):
    if ref not in inputs:
        error(f"expression refers to undefined input '{ref}'")
for sid, out in sorted(set(re.findall(r"steps\.([A-Za-z0-9_-]+)\.outputs\.([A-Za-z0-9_-]+)", raw))):
    if sid not in step_ids:
        error(f"expression refers to undefined step id '{sid}'")
ok("expression references resolve")

unused = [n for n in inputs if f"inputs.{n}" not in raw]
if unused:
    error(f"inputs never used by a step: {unused}")
else:
    ok("every input is used")

with open("README.md", encoding="utf-8") as handle:
    readme = handle.read()
for name in inputs:
    if not re.search(rf"^\| `{re.escape(name)}` \|", readme, re.M):
        error(f"input '{name}' is missing from the README inputs table")
for name in outputs:
    if f"`{name}`" not in readme:
        error(f"output '{name}' is not mentioned in the README")
ok("README documents every input and output")

# Variables the scripts read from the environment must be set by the step that runs them.
render_step = next(s for s in steps if s.get("id") == "render")
provided = set(render_step.get("env", {}))
with open("scripts/render.sh", encoding="utf-8") as handle:
    script = handle.read()
read_vars = set(re.findall(r"^([A-Z_]+)=\$\{\1[-:]", script, re.M))
not_provided = sorted(v for v in read_vars if v not in provided)
if not_provided:
    error(f"scripts/render.sh reads variables the render step does not set: {not_provided}")
else:
    ok("render step provides every variable scripts/render.sh reads")

pm_step = next(s for s in steps if s.get("id") == "pm")
with open("scripts/detect-package-manager.sh", encoding="utf-8") as handle:
    detect = handle.read()
detect_vars = set(re.findall(r"^([A-Z_]+)=\$\{\1[-:]", detect, re.M))
not_provided = sorted(v for v in detect_vars if v not in set(pm_step.get("env", {})))
if not_provided:
    error(f"detect-package-manager.sh reads variables the pm step does not set: {not_provided}")
else:
    ok("pm step provides every variable detect-package-manager.sh reads")

print("pinned actions")
sha = re.compile(r"^[^@\s]+@[0-9a-f]{40}$")
files = ["action.yml"] + sorted(glob.glob(".github/workflows/*.yml")) + sorted(glob.glob("examples/*.yml"))
checked = 0
for path in files:
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            match = re.match(r"\s*-?\s*uses:\s*(\S+)", line)
            if not match:
                continue
            target = match.group(1)
            if target.startswith("./"):
                continue
            # Examples show how consumers call this action, which they pin by tag.
            if path.startswith("examples/"):
                continue
            checked += 1
            if not sha.match(target):
                error(f"{path}:{number} uses '{target}' without a full commit SHA")
            elif "#" not in line:
                error(f"{path}:{number} pins a SHA without a version comment")
ok(f"{checked} workflow/action references pinned to a SHA")

# ---------------------------------------------------------------------------
# Documentation: snippets and links
# ---------------------------------------------------------------------------
DOCS = ["README.md", "AGENTS.md", "CONTRIBUTING.md", "llms.txt", "CHANGELOG.md"] + sorted(glob.glob("docs/*.md"))
ACTION_REF = re.compile(r"^LLazyEmail/email-template-workflows@")


def yaml_blocks(path):
    """Yield (line number, text) for every ```yaml / ```yml fenced block."""
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    for match in re.finditer(r"^```(?:yaml|yml)[ \t]*\n(.*?)^```[ \t]*$", text, re.M | re.S):
        yield text.count("\n", 0, match.start()) + 2, match.group(1)


def action_calls(node):
    """Yield every mapping in a parsed YAML tree that calls this Action."""
    if isinstance(node, dict):
        uses = node.get("uses")
        if isinstance(uses, str) and ACTION_REF.match(uses):
            yield node
        for value in node.values():
            yield from action_calls(value)
    elif isinstance(node, list):
        for item in node:
            yield from action_calls(item)


def check_calls(label, tree):
    count = 0
    for call in action_calls(tree):
        count += 1
        if not call["uses"].endswith("@v1"):
            error(f"{label}: '{call['uses']}' must be pinned to @v1")
        for key in (call.get("with") or {}):
            if key not in inputs:
                error(f"{label}: '{key}' is not an input of this action")
    return count


print("documentation snippets")
snippets = 0
calls = 0
for path in DOCS:
    for line, block in yaml_blocks(path):
        snippets += 1
        label = f"{path}:{line}"
        try:
            tree = yaml.safe_load(block)
        except yaml.YAMLError as exc:
            error(f"{label}: YAML snippet does not parse ({str(exc).splitlines()[0]})")
            continue
        calls += check_calls(label, tree)
for path in sorted(glob.glob("examples/*.yml")):
    with open(path, encoding="utf-8") as handle:
        calls += check_calls(path, yaml.safe_load(handle))
ok(f"{snippets} YAML snippets parse; {calls} calls to this action use only real inputs")

print("documentation links")


def slug(heading):
    """GitHub's heading anchor: lowercase, drop punctuation, spaces to hyphens."""
    heading = re.sub(r"[`*_]", "", heading.strip().lower())
    heading = re.sub(r"[^\w\- ]", "", heading)
    return heading.replace(" ", "-")


anchor_cache = {}


def anchors(path):
    if path not in anchor_cache:
        found = set()
        in_fence = False
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("```"):
                    in_fence = not in_fence
                elif not in_fence:
                    match = re.match(r"#{1,6}\s+(.*)", line)
                    if match:
                        found.add(slug(match.group(1)))
        anchor_cache[path] = found
    return anchor_cache[path]


links = 0
for path in DOCS:
    with open(path, encoding="utf-8") as handle:
        text = re.sub(r"```.*?```", "", handle.read(), flags=re.S)
    for target in re.findall(r"\]\(([^)\s]+)\)", text):
        if re.match(r"[a-z][a-z0-9+.-]*:", target):
            continue
        file_part, _, fragment = target.partition("#")
        resolved = os.path.normpath(os.path.join(os.path.dirname(path), file_part)) if file_part else path
        links += 1
        if not os.path.exists(resolved):
            error(f"{path}: link '{target}' points at a file that does not exist")
        elif fragment and resolved.endswith(".md") and fragment not in anchors(resolved):
            error(f"{path}: link '{target}' points at a heading that does not exist")
ok(f"{links} relative links resolve")

print()
if errors:
    print(f"{len(errors)} problem(s)")
    sys.exit(1)
print("all checks passed")

"""Validate rule files and build the merged rules section of README.md.

Usage:
    python build/build_rules.py           # validate, then rewrite README.md
    python build/build_rules.py --check   # validate, fail if README.md is stale (MR pipelines)
"""
import pathlib
import re
import sys

import frontmatter
from jinja2 import Environment, FileSystemLoader

ROOT = pathlib.Path(__file__).resolve().parent.parent
RULES_DIR = ROOT / "rules"
README = ROOT / "README.md"
TEMPLATE_DIR = ROOT / "build" / "templates"
START, END = "<!-- RULES:START -->", "<!-- RULES:END -->"

# Closed lists: only the standard owner changes these, via MR
SCOPES = {"GE": "General", "FE": "Frontend", "BE": "Backend"}
SEVERITIES = ["Blocker", "Major", "Minor", "Info"]
STATUSES = ["Draft", "Active", "Deprecated"]
REQUIRED_FIELDS = ["id", "title", "severity", "status", "applied_to"]
REQUIRED_SECTIONS = ["Description", "Bad", "Good"]
ID_PATTERN = re.compile(r"^(GE|FE|BE)-\d{3}$")


def normalize_key(key):
    # Frontmatter keys are case/space tolerant: "Applied to" -> "applied_to", "ID" -> "id"
    return str(key).strip().lower().replace(" ", "_")


def validate(path, meta, content):
    """Return a list of error strings for one rule file."""
    rel = path.relative_to(ROOT).as_posix()
    errors = []

    missing = [f for f in REQUIRED_FIELDS if not meta.get(f)]
    if missing:
        return [f"{rel}: missing frontmatter fields {missing}"]

    rid = meta["id"]
    if not ID_PATTERN.match(rid):
        errors.append(f"{rel}: invalid ID '{rid}' (expected GE|FE|BE-NNN)")
    else:
        if path.stem != rid:
            errors.append(f"{rel}: file name must equal ID ({rid}.md)")
        if path.parent.name != rid.split("-")[0]:
            errors.append(f"{rel}: must be in folder rules/{rid.split('-')[0]}/")

    if meta["severity"] not in SEVERITIES:
        errors.append(f"{rel}: Severity '{meta['severity']}' not in {SEVERITIES}")
    if meta["status"] not in STATUSES:
        errors.append(f"{rel}: Status '{meta['status']}' not in {STATUSES}")
    if not isinstance(meta["applied_to"], list):
        errors.append(f"{rel}: 'Applied to' must be a list, e.g. [plugin, webjob]")

    sections = re.findall(r"^##\s+(.+?)\s*$", content, flags=re.MULTILINE)
    missing_sections = [s for s in REQUIRED_SECTIONS if s not in sections]
    if missing_sections:
        errors.append(f"{rel}: missing sections {missing_sections}")
    return errors


def load_rules():
    rules, errors, seen = [], [], {}
    for path in sorted(RULES_DIR.rglob("*.md")):
        if path.name.startswith("_"):  # skip helper files such as _TEMPLATE.md
            continue
        rel = path.relative_to(ROOT).as_posix()
        try:
            post = frontmatter.load(path)
        except Exception as exc:  # malformed YAML frontmatter
            errors.append(f"{rel}: cannot parse frontmatter ({exc})")
            continue

        meta = {normalize_key(k): v for k, v in post.metadata.items()}
        if meta.get("id"):
            meta["id"] = str(meta["id"]).strip()

        file_errors = validate(path, meta, post.content)
        if file_errors:
            errors.extend(file_errors)
            continue

        rid = meta["id"]
        if rid in seen:
            errors.append(f"{rel}: duplicate ID {rid} (already used by {seen[rid]})")
            continue
        seen[rid] = rel

        # Demote rule sections so they nest under the rule heading in README
        body = re.sub(r"^## ", "#### ", post.content.strip(), flags=re.MULTILINE)
        rules.append({**meta, "scope": rid.split("-")[0], "path": rel, "body": body})

    # Cross-file check: replaced_by must point to an existing rule
    for r in rules:
        target = r.get("replaced_by")
        if target and target not in seen:
            errors.append(f"{r['path']}: 'Replaced by' points to unknown ID {target}")

    scope_order = list(SCOPES)
    rules.sort(key=lambda r: (scope_order.index(r["scope"]), r["id"]))
    return rules, errors


def render(rules):
    by_status = {s: [r for r in rules if r["status"] == s] for s in STATUSES}
    active_by_scope = {
        code: [r for r in by_status["Active"] if r["scope"] == code] for code in SCOPES
    }
    env = Environment(
        loader=FileSystemLoader(TEMPLATE_DIR), trim_blocks=True, lstrip_blocks=True
    )
    text = env.get_template("readme.md.j2").render(
        scopes=SCOPES,
        active_by_scope=active_by_scope,
        active_count=len(by_status["Active"]),
        drafts=by_status["Draft"],
        deprecated=by_status["Deprecated"],
    )
    # Collapse blank-line runs left by template control blocks
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def main():
    check_only = "--check" in sys.argv

    rules, errors = load_rules()
    if errors:
        print("Rule validation failed:")
        for e in errors:
            print(f"  - {e}")
        return 1

    readme = README.read_text(encoding="utf-8")
    if START not in readme or END not in readme:
        print(f"README.md must contain both markers: {START} and {END}")
        return 1

    head, rest = readme.split(START, 1)
    tail = rest.split(END, 1)[1]
    new_readme = f"{head}{START}\n{render(rules)}\n{END}{tail}"

    if check_only:
        if new_readme != readme:
            print("README.md is out of date. Run: python build/build_rules.py")
            return 1
        print(f"OK: {len(rules)} rules valid, README.md up to date.")
        return 0

    # Always write LF so Windows and CI produce identical output
    with open(README, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_readme)
    print(f"README.md rebuilt from {len(rules)} rules.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

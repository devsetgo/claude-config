#!/usr/bin/env python3
"""Validate skills/*/SKILL.md frontmatter and check README.md's skill index stays in sync."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS_DIR = ROOT / "skills"
README = ROOT / "README.md"

errors = []

# Orchestrators end in -check but run inline; every other *-check skill is a
# forked sub-agent (see CLAUDE.md and skills/_shared/finding-format.md).
ORCHESTRATORS = {"dsg-pr-check", "dsg-release-check"}
FORK_FIELDS = {"context": "fork", "model": "sonnet", "background": "false"}
SHARED_DIR = SKILLS_DIR / "_shared"


def check_shared_refs(label, text):
    # Skills run inside other projects, where a repo-root skills/_shared/
    # path doesn't exist; reference shared docs relative to the skill dir.
    for m in re.finditer(r"(?<![\w./}])skills/_shared/", text):
        line = text.count("\n", 0, m.start()) + 1
        errors.append(f"{label}:{line}: use ../_shared/... (relative to the skill dir), not skills/_shared/...")
    for ref in sorted(set(re.findall(r"\.\./_shared/([\w.-]+\.md)", text))):
        if not (SHARED_DIR / ref).exists():
            errors.append(f"{label}: references ../_shared/{ref}, which doesn't exist")

skill_dirs = sorted(
    p.name
    for p in SKILLS_DIR.iterdir()
    # synced/ is Claude Code's account-synced skills (gitignored), not ours.
    if p.is_dir() and not p.name.startswith("_") and p.name != "synced"
)

for name in skill_dirs:
    skill_md = SKILLS_DIR / name / "SKILL.md"
    if not skill_md.exists():
        errors.append(f"skills/{name}/ has no SKILL.md")
        continue

    text = skill_md.read_text()
    match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        errors.append(f"skills/{name}/SKILL.md: missing YAML frontmatter (--- ... ---)")
        continue

    frontmatter = match.group(1)
    name_match = re.search(r"^name:\s*(.+)$", frontmatter, re.MULTILINE)
    desc_match = re.search(r"^description:\s*(.+)$", frontmatter, re.MULTILINE)

    if not name_match:
        errors.append(f"skills/{name}/SKILL.md: frontmatter missing 'name'")
    elif name_match.group(1).strip() != name:
        errors.append(
            f"skills/{name}/SKILL.md: frontmatter name '{name_match.group(1).strip()}' "
            f"does not match directory name '{name}'"
        )

    if not desc_match or desc_match.group(1).strip() in ("", ">", "|", ">-", "|-"):
        errors.append(f"skills/{name}/SKILL.md: frontmatter missing a one-line 'description'")

    if name.endswith("-check") and name not in ORCHESTRATORS:
        for key, value in FORK_FIELDS.items():
            if not re.search(rf"^{key}:\s*{value}\s*$", frontmatter, re.MULTILINE):
                errors.append(f"skills/{name}/SKILL.md: *-check skills need '{key}: {value}' in frontmatter")
        if "../_shared/finding-format.md" not in text[match.end():]:
            errors.append(f"skills/{name}/SKILL.md: body must point the fork at ../_shared/finding-format.md")

    check_shared_refs(f"skills/{name}/SKILL.md", text)

for doc in sorted(SHARED_DIR.glob("*.md")):
    check_shared_refs(f"skills/_shared/{doc.name}", doc.read_text())

readme_text = README.read_text()
linked_skills = set(re.findall(r"\[([a-z0-9-]+)\]\(skills/\1/SKILL\.md\)", readme_text))

for name in sorted(set(skill_dirs) - linked_skills):
    errors.append(f"README.md: skills table is missing an entry for '{name}'")
for name in sorted(linked_skills - set(skill_dirs)):
    errors.append(f"README.md: skills table lists '{name}', which no longer exists under skills/")


def slug(heading):
    # GitHub's anchor slugs: lowercase, drop punctuation, spaces to hyphens.
    return re.sub(r"[^\w\- ]", "", heading.strip().lower()).replace(" ", "-")


anchors = {slug(h) for h in re.findall(r"^#+\s+(.+)$", readme_text, re.MULTILINE)}
for target in re.findall(r"\]\(([^)\s]+)\)", readme_text):
    if re.match(r"^[a-z]+:", target):
        continue  # external URL
    path, _, anchor = target.partition("#")
    if path and not (ROOT / path).exists():
        errors.append(f"README.md: link to '{path}', which doesn't exist")
    if not path and anchor and anchor not in anchors:
        errors.append(f"README.md: link to '#{anchor}', which matches no heading")

if errors:
    print("skill-lint found problems:\n")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print(f"skill-lint OK ({len(skill_dirs)} skills checked)")

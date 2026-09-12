#!/usr/bin/env python3
"""Validate skills/*/SKILL.md frontmatter and check README.md's skill index stays in sync."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS_DIR = ROOT / "skills"
README = ROOT / "README.md"

errors = []

skill_dirs = sorted(
    p.name for p in SKILLS_DIR.iterdir() if p.is_dir() and not p.name.startswith("_")
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

    if not desc_match or not desc_match.group(1).strip():
        errors.append(f"skills/{name}/SKILL.md: frontmatter missing 'description'")

readme_text = README.read_text()
linked_skills = set(re.findall(r"\[([a-z0-9-]+)\]\(skills/\1/SKILL\.md\)", readme_text))

for name in sorted(set(skill_dirs) - linked_skills):
    errors.append(f"README.md: skills table is missing an entry for '{name}'")
for name in sorted(linked_skills - set(skill_dirs)):
    errors.append(f"README.md: skills table lists '{name}', which no longer exists under skills/")

if errors:
    print("skill-lint found problems:\n")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print(f"skill-lint OK ({len(skill_dirs)} skills checked)")

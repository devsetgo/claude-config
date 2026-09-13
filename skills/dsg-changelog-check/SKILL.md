---
name: dsg-changelog-check
description: Keep CHANGELOG.md current for user-facing changes — skips repos where Release Drafter (or an equivalent release-notes action) already generates it from PR metadata. Use standalone after finishing a change, or as part of dsg-pr-check.
---

# Changelog Check

Most changelog automation works from PR titles/labels, not a hand-maintained
file — check for that first so this skill doesn't fight with existing
tooling.

## Steps

1. Check whether this repo already automates its changelog/release notes:
   - `.github/release-drafter.yml` (or equivalent path) present, and/or
   - a GitHub Actions workflow referencing `release-drafter/release-drafter`
   - any other changelog-generation action (e.g. `semantic-release`,
     `github-changelog-generator`)

   If found, this check is **N/A** — don't hand-edit `CHANGELOG.md`, it
   would drift from what the automation generates instead. Note which
   tool was found. Optionally sanity-check that the tool's category
   config (e.g. Release Drafter's `autolabeler`/`categories`) actually
   lines up with the labels/title conventions this repo's PRs use — see
   the `dsg-commit` skill for the drafting side of that.

2. If no changelog automation is found, look for `CHANGELOG.md` (or
   `HISTORY.md`, `docs/CHANGELOG.md`). If none exists, ask before creating
   one — that's a project-level decision, not something to introduce
   silently.

3. Walk the diff (or the commits since the last release tag, if invoked
   standalone rather than mid-diff) for user-facing changes: new
   features, bug fixes, breaking changes, deprecations. Skip purely
   internal refactors, test-only changes, and tooling/CI changes unless
   this project's existing changelog entries show it tracks those too.

4. Classify each entry using whatever categories the existing
   `CHANGELOG.md` already uses (commonly Keep a Changelog's `Added`/
   `Changed`/`Fixed`/`Deprecated`/`Removed`/`Security`) — match the file's
   existing structure and voice rather than inventing a new one.

## Output

- **Standalone** (invoked directly, e.g. right after finishing a change):
  add the entries to `CHANGELOG.md` under its "Unreleased" section (or
  equivalent), matching its existing format. Flag anything ambiguous
  (e.g. which section a change belongs in) rather than guessing silently.
- **Delegated from another skill** (e.g. `dsg-pr-check`): don't write to the
  file — return findings (what's missing, suggested entry text) so the
  caller can add them to its own task list instead.
- **Release Drafter (or equivalent) present**: report `N/A` and which
  tool was found; no file edits.

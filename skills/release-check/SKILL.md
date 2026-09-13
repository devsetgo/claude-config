---
name: release-check
description: Run a pre-release gate for cutting an actual release/tag — version-bump consistency, changelog freshness, API contract breakage, and a full dependency audit across everything since the last release, not just the current diff. Use when cutting a release, as distinct from pr-check's per-PR gate.
---

# Release Check

A gate for the moment of cutting a release — distinct from `pr-check`,
which gates individual PRs against a single diff. This looks at everything
accumulated since the last release, not just one diff.

## Before running any checks

Find the last release tag (e.g. `git describe --tags --abbrev=0`) and use
the range from there to `HEAD` as the scope for every check below, instead
of a single PR's diff. Also read this project's own standards docs
(`CLAUDE.md`, `CONTRIBUTING.md`, `PROJECT_STATUS.md`) if present — the same
precedence rule as `pr-check` applies: project conventions win over the
generic guidance here.

## Checklist

1. **Version bump consistency** — delegate to the `version-bump-check`
   skill.

2. **Changelog freshness** — delegate to the `changelog-check` skill,
   scoped to the full commit range since the last tag. Still `N/A` on
   repos where Release Drafter (or equivalent) owns the changelog.

3. **API contract breakage** — delegate to the `api-contract-check`
   skill, comparing the contract at the last release tag against `HEAD`
   rather than a single diff. Under semantic versioning, a `BREAKING`
   finding here should correspond to a major version bump — cross-check
   against item 1 and flag a mismatch as its own finding. Under calendar
   versioning (e.g. a BumpCalver-configured project — see
   `version-bump-check`), the version number won't encode this at all, so
   instead confirm the breaking change is called out prominently in the
   changelog/release notes (item 2) rather than expecting a version-number
   signal.

4. **Dependency audit** — delegate to the `dependency-audit-check` skill,
   run over the full dependency tree rather than diff-touched packages
   only. A release is a natural checkpoint for catching drift that
   accumulated silently across several merged PRs.

5. **Release automation sanity** — if this repo uses Release Drafter (or
   similar), confirm the draft release notes it has accumulated look
   complete and correctly categorized: no merged PR carrying a label the
   autolabeler doesn't map to a category, no "uncategorized" section with
   real content sitting in it.

## Output format

Report each item as one line: `PASS` / `FAIL` / `N/A` plus a one-sentence
reason, same convention as `pr-check`.

On any FAIL, merge findings into the same shared `TODO_TASKS.md` worklist
`pr-check` uses — see `skills/_shared/task-list.md` for the file
location, structure, dedup rules, and the cleanup pass to run every time
(including runs with zero new findings). Tag each item
`[release-check, <date>]` per that convention.

Don't fix anything automatically unless asked — this is a gate, not an
auto-fixer. Once everything passes, drafting the actual release notes or
tag message is the `commit-message` skill's job (or Release Drafter's, if
configured) — this skill only gates readiness.

---
name: dsg-release-check
description: Run a pre-release gate for cutting an actual release/tag — version-bump consistency, changelog freshness, API contract breakage, and a full dependency audit across everything since the last release, not just the current diff. Use when cutting a release, as distinct from dsg-pr-check's per-PR gate.
---

# Release Check

A gate for the moment of cutting a release — distinct from `dsg-pr-check`,
which gates individual PRs against a single diff. This looks at everything
accumulated since the last release, not just one diff.

## Before running any checks

Find the last release tag: the most recent tag matching this project's
release tag format (`git tag --sort=-v:refname`; `git describe --tags
--abbrev=0` can pick up an unrelated tag). Use the range from there to
`HEAD` as the scope for every check below, instead of a single PR's
diff. Also read this project's own standards docs
(`CLAUDE.md`, `CONTRIBUTING.md`, `PROJECT_STATUS.md`) if present — the same
precedence rule as `dsg-pr-check` applies: project conventions win over the
generic guidance here.

## How delegated checks run

The focused `dsg-*-check` skills run as forked sub-agents on `sonnet`;
see `../_shared/finding-format.md`, relative to this skill's directory.
A forked check can't see this conversation, so:

- **Pass the scope explicitly.** Invoke each with
  `delegated-from=dsg-release-check base=<last release tag>
  category="<checklist item name>" docs=<comma-separated paths>`.
  - Add `scope=full-tree` for `dsg-dep-check` (item 4).
  - If the repo has no release tag yet, say so and pass the empty tree
    (`git hash-object -t tree /dev/null`) as the base, so the first
    commit's own changes are included.
- **Start items 1–4 in one turn,** as several Skill calls in a single
  message, then do item 5 inline. Take each check's findings as
  returned, and map them the way `dsg-pr-check` does: `Not applicable`
  is `N/A`, a "not run" finding is `FAIL`. Re-invoke a failed check
  once, then report it as `FAIL` with "check didn't complete".

## Checklist

1. **Version bump consistency** — delegate to the `dsg-version-check`
   skill.

2. **Changelog freshness** — delegate to the `dsg-changelog-check` skill,
   scoped to the full commit range since the last tag. Still `N/A` on
   repos where Release Drafter (or equivalent) owns the changelog.

3. **API contract breakage** — delegate to the `dsg-api-check`
   skill, comparing the contract at the last release tag against `HEAD`
   rather than a single diff. Under semantic versioning, a `BREAKING`
   finding here should correspond to a major version bump — cross-check
   against item 1 and flag a mismatch as its own finding. Under calendar
   versioning (e.g. a BumpCalver-configured project — see
   `dsg-version-check`), the version number won't encode this at all, so
   instead confirm the breaking change is called out prominently in the
   changelog/release notes (item 2) rather than expecting a version-number
   signal.

4. **Dependency audit** — delegate to the `dsg-dep-check` skill,
   run over the full dependency tree rather than diff-touched packages
   only. A release is a natural checkpoint for catching drift that
   accumulated silently across several merged PRs.

5. **Release automation sanity** — if this repo uses Release Drafter (or
   similar), confirm the draft release notes it has accumulated look
   complete and correctly categorized: no merged PR carrying a label the
   autolabeler doesn't map to a category, no "uncategorized" section with
   real content sitting in it. If the draft already has a tag set, it must
   match the declared version exactly, following the project's tag
   convention (with or without a `v`).

## Output format

Report each item as one line: `PASS` / `FAIL` / `N/A` plus a one-sentence
reason, same convention as `dsg-pr-check`.

Then, on every run, update the same shared `TODO_TASKS.md` worklist
`dsg-pr-check` uses. Run its cleanup pass even when everything passes,
and add items only for `FAIL`s. See `../_shared/task-list.md` for the file
location, structure, dedup rules, and the cleanup pass. Tag each item
`[dsg-release-check, <date>, <severity>]` per that convention, using the
same severity defaults `dsg-pr-check` uses.

Don't fix anything automatically unless asked — this is a gate, not an
auto-fixer. Once everything passes, drafting the actual release notes or
tag message is the `dsg-commit` skill's job (or Release Drafter's, if
configured) — this skill only gates readiness.

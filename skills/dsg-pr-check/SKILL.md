---
name: dsg-pr-check
description: Run a pre-PR standards review — test coverage gaps, security, documentation freshness, comment quality, schema-migration coverage, ignore-file hygiene, dependency audit, error handling, secrets/config drift, changelog freshness, and API contract breakage. Use before opening a PR. For cutting an actual release, use `dsg-release-check` instead.
---

# PR Readiness Check

A standards gate to run before opening a PR, scoped to the current diff.
For the separate moment of cutting a release — which should look at
everything accumulated since the last tag, not just one diff — use the
`dsg-release-check` skill instead. It combines delegated review (existing
Claude Code skills) with a handful of checks that are typically
project-specific. Report a pass/fail/n-a summary, then turn any failures
into `TODO_TASKS.md` entries to work through one at a time. Don't fix
anything automatically unless asked; this produces a worklist, not an
auto-fixer.

## Before running any checks

Look for this project's own standards docs (commonly named `CLAUDE.md`,
`CONTRIBUTING.md`, `PROJECT_STATUS.md`, or similar) and read them first.
Project-specific conventions found there (test safety rules, naming
patterns, what "done" means for this repo) take precedence over the
generic guidance below.

## Checklist

1. **Test coverage gaps** — delegate to the `dsg-coverage-check` skill.

2. **Security** — delegate to the `security-review` skill/command if
   available in this environment; otherwise perform a manual pass for the
   OWASP-top-10-shaped issues (injection, auth bypass, secrets in code,
   unsafe deserialization, SSRF, etc.) on the changed files.

3. **Correctness / simplification** — delegate to the `code-review`
   skill/command if available; otherwise review the diff directly for
   correctness bugs and obvious simplification opportunities.

4. **Documentation freshness** — delegate to the `dsg-doc-check` skill.

5. **Comment coverage** — delegate to the `dsg-comment-check` skill.

6. **Schema/migration coverage** — if this project uses a migration tool
   (Alembic, Django migrations, Prisma, etc.) and the diff changes a
   database schema, confirm a migration was generated/committed for it.
   If the project has no migration tooling yet (e.g. a dev-only
   create-tables-on-boot pattern), note that this check is only
   meaningful once real migrations exist — don't fail the check on a
   project that hasn't adopted migrations yet.

7. **Ignore-file hygiene** — check whether the diff introduces new
   generated artifacts, local-only files, or secrets-adjacent files that
   `.gitignore`/`.dockerignore` don't yet cover.

8. **Dependency audit** — delegate to the `dsg-dep-check` skill.

9. **Error handling** — delegate to the `dsg-error-check` skill.

10. **Secrets & config drift** — delegate to the `dsg-secrets-check` skill.

11. **Changelog freshness** — delegate to the `dsg-changelog-check` skill.
    Expect `N/A` on repos using Release Drafter or similar automation;
    that's correct behavior, not a skipped check.

12. **API contract breakage** — delegate to the `dsg-api-check`
    skill. `N/A` if the diff doesn't touch a public API/schema/library
    contract.

Once the PR is ready to commit, use the separate `dsg-commit` skill
to draft the commit message/PR title — it's a drafting step, not a
pass/fail item, so it isn't part of this checklist.

## Output format

First, report each of the 12 items as one line: `PASS` / `FAIL` / `N/A`
plus a one-sentence reason. This summary is printed to the conversation,
not the task list file.

Then merge findings into the shared `TODO_TASKS.md` worklist — see
`skills/_shared/task-list.md` for the file location, structure, dedup
rules, and the cleanup pass to run every time (including runs with zero
new findings). Tag each item `[dsg-pr-check, <date>]` per that convention.

After updating the file, stop — don't start fixing issues unless asked.
Findings are meant to be worked through one at a time (with the user, or
in a follow-up turn): pick an item, fix it, re-run the relevant check to
confirm, then check it off (`- [x]`). Don't batch-fix the whole list in
one pass.

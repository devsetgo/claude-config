---
name: doc-freshness-check
description: Check whether new settings, endpoints, tables, or behavior changes in the diff are reflected in this project's own standards docs. Use standalone or as part of pr-check.
---

# Documentation Freshness Check

Confirm the diff didn't change externally-visible behavior without a
corresponding doc update.

## Steps

1. Find this project's own standards docs — commonly `CLAUDE.md`,
   `CONTRIBUTING.md`, `PROJECT_STATUS.md`, a `docs/` directory, or an
   OpenAPI/schema spec. Read them before judging anything stale.
2. Walk the diff for anything a doc reader would need to know about:
   - new or changed config/settings/env vars
   - new or changed API endpoints/routes
   - new or changed database tables/columns
   - non-obvious behavior changes (defaults, error handling, side effects)
3. For each, check whether it's mentioned anywhere in the docs found in
   step 1. A passing mention counts — this isn't demanding prose, just
   that the fact is discoverable.
4. Ignore purely internal refactors with no externally-visible behavior
   change — those don't need doc updates.

## Output

A list of undocumented changes, each with: file:line of the change, what's
undocumented, and where it should probably go (which existing doc/section,
or "no docs dir exists yet" if none fits). See
`skills/_shared/finding-format.md` for the standalone-vs-delegated
reporting convention.

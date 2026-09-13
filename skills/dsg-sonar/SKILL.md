---
name: dsg-sonar
description: Pull open SonarQube/SonarCloud issues for a branch or the whole project via the Sonar API, dismiss genuine false positives (with a recorded justification), and fix the rest in reviewable batches — keeping TODO_TASKS.md current on what's fixed vs remaining. Use to work through a Sonar issue backlog.
---

# Sonar Cleanup

Works through a project's SonarQube/SonarCloud backlog: pulls issues via
the API (not by re-running analysis), separates real problems from false
positives, and fixes the real ones in batches small enough to review.

## Scope

Accepts an optional scope argument: a branch name, or `all`/`main` for
the whole project's current baseline. Default: the current git branch.

If the requested branch has no Sonar analysis yet (CI hasn't pushed
results for it), say so and offer to fall back to the main/default
branch's baseline instead of silently returning nothing.

## Before running

1. Find this project's Sonar config: `sonar-project.properties`
   (`sonar.projectKey`, `sonar.organization`, `sonar.host.url`), or a CI
   workflow referencing `sonarsource/sonarcloud-github-action` /
   `sonar-scanner`. If none of these exist, this skill doesn't apply to
   this project — say so rather than guessing a project key.
2. Confirm an API token is available (`SONAR_TOKEN` env var, or whatever
   name this project's CI secret uses — check the workflow for the actual
   variable name). Never print the token or write it to a file; if it's
   missing, ask the user to export it rather than trying to source it
   yourself from anywhere.

   If it's missing, walk the user through getting one before going any
   further — don't just say "set SONAR_TOKEN" and stop:
   - **Generate a token**: in the Sonar UI, under the user's own account —
     **My Account → Security** (same path on SonarCloud and self-hosted
     SonarQube) — name it something identifiable (e.g. the project or
     "claude-code"), and set an expiry if the org's policy expects one.
     A token needs at least browse/read access to the project this skill
     is targeting; it only needs write access too if the user wants this
     skill to dismiss false positives (`Administer Issues` permission) —
     mention that distinction rather than assuming they want the broader
     scope.
   - **Where to put it, locally**: export it as `SONAR_TOKEN` in the
     shell — a `.env`/`.envrc` the project already loads if it has one,
     otherwise the user's own shell profile. Never suggest committing it
     to a tracked file or hardcoding it into `sonar-project.properties`.
   - **Where to put it, for CI**: as a repository/organization secret
     named to match whatever the CI workflow already reads (check
     `.github/workflows/*.yml` for the env var name it expects — often
     `SONAR_TOKEN`) — e.g. GitHub: repo **Settings → Secrets and
     variables → Actions**. Only mention this path if the user's asking
     about CI failing, not local runs of this skill.
   - Once they've exported it in the current shell, re-check for it
     rather than asking them to restart or re-invoke the skill.
3. Determine the host: `https://sonarcloud.io` unless
   `sonar.host.url` says otherwise (self-hosted SonarQube). SonarCloud
   requests need an `organization` param; self-hosted requests don't.

## Fetching issues

Use `GET /api/issues/search` (paginate with `p`/`ps`, max `ps=500` per
page) filtered to `resolved=false`, scoped with `componentKeys` + the
target `branch` (omit `branch` entirely for the main/default baseline —
passing it is what makes this branch-scoped instead of whole-app).

Also query `/api/hotspots/search` separately — Security Hotspots use a
different status model (`TO_REVIEW`/`REVIEWED`, resolution `SAFE`/
`FIXED`) and a different endpoint from regular issues; don't lump them
into the same request or the same classification pass.

Authenticate with HTTP Basic auth, the token as username, empty password:
`curl -u "$SONAR_TOKEN:" ...`.

## Classifying each issue

For every open issue/hotspot, decide:

- **False positive** — the rule's stated concern genuinely doesn't apply
  given context Sonar's static analysis can't see: e.g. a security
  hotspot on input already sanitized by a vetted helper a few lines up, a
  cognitive-complexity flag on a dispatch table that's exhaustive by
  necessity and wouldn't get clearer split apart, a duplication flag on
  blocks that look similar but evolve independently (merging them would
  add unwanted coupling). Being inconvenient to fix is never sufficient
  justification by itself — when genuinely unsure, treat it as real and
  put it on the worklist instead of dismissing it.
- **Real issue** — everything else. Classify by Sonar's own type (`BUG`,
  `VULNERABILITY`, `CODE_SMELL`) or hotspot category; that's what
  determines the fix shape (a bug needs a logic fix, a code smell needs a
  refactor, a vulnerability needs the unsafe pattern actually removed).

Present the false-positive list to the user before dismissing anything —
dismissing changes shared state visible to the whole team on Sonar's
dashboard, so this needs confirmation, not a silent auto-dismiss. On
confirmation: dismiss via `POST /api/issues/do_transition`
(`transition=falsepositive` or `wontfix`, whichever fits) and leave a
comment via `POST /api/issues/add_comment` explaining why — a future
reader (human or the next analysis run) needs the reasoning, not just a
status flip. For hotspots, use `POST /api/hotspots/change_status` with
`resolution=SAFE` plus a comment.

## Fixing real issues, in batches

Don't attempt everything in one pass when there are many issues. Batch by
file or by a fixed count (roughly 10-15 issues per batch stays
reviewable); within each batch, prioritize `BUG`/`VULNERABILITY` and
higher severity first. After each batch: fix, run the project's test
suite, then move to the next batch — don't queue every fix across the
whole backlog before testing any of them.

Don't manually mark a fixed *real* issue resolved via the API — once the
fix is pushed and CI re-analyzes, Sonar closes it itself by noticing the
flagged code no longer matches. Manual dismissal is only for false
positives, where the flagged code intentionally stays as-is.

## Keeping TODO_TASKS.md current

Follow `skills/_shared/task-list.md` for the shared file, structure, and
cleanup convention. A few things specific to this skill:

- Tag each item `[dsg-sonar, <date>, <severity>]` and include the Sonar
  issue key in the item text itself (e.g. `... (issue AbCd1234)`) — that
  key is what makes cleanup precise instead of guesswork.
- Map Sonar's own severity straight onto the shared scale: `BLOCKER`/
  `CRITICAL` → `critical`, `MAJOR` → `high`, `MINOR` → `medium`, `INFO` →
  `low`. For hotspots (no severity field), use the hotspot's own
  vulnerability probability (`HIGH`/`MEDIUM`/`LOW`) directly as the tier.
- Group items under `Sonar — Bugs`, `Sonar — Vulnerabilities`,
  `Sonar — Code Smells`, and `Sonar — Security Hotspots` headings.
- Cleanup pass: instead of re-grepping code like the generic convention
  describes, re-query `/api/issues/search?issues=<key1>,<key2>,...` (or
  the hotspots equivalent) for every open item's key and drop any that
  come back resolved/closed. This is more reliable than the generic
  re-verification step, since Sonar tracks resolution directly rather
  than needing to be inferred. Still apply the 14-day pruning rule for
  already-checked items.

## Output

Report counts up front (open issues by type/severity, hotspots, false
positives found). A plain PASS/FAIL summary doesn't fit this skill the
way it fits the `*-check` family — this is a backlog to work down, not a
gate — so instead report "N fixed this run, M dismissed as false
positive, K remaining in `TODO_TASKS.md`."

---
name: dsg-actions
description: Pull failing GitHub Actions runs for a branch/PR via the gh CLI (or the REST API if gh isn't available), pull out the actual error from the log instead of the whole dump, tell flaky/infra failures apart from real ones, and fix the real ones in batches — keeping TODO_TASKS.md current. Use instead of copy-pasting failed-run logs into chat.
---

# GitHub Actions Failure Triage

Connects to the run directly instead of you copy-pasting log output into
the conversation. Pulls the failing step(s), isolates the actual error
from surrounding noise, tells a real code problem apart from a flaky/
infra failure, and fixes what's actually broken.

## Before running

1. Check for `gh` (GitHub CLI) and that it's authenticated (`gh auth
   status`). If `gh` isn't installed, fall back to the REST API directly
   with `curl` against `api.github.com`, authenticated with a
   `GITHUB_TOKEN`/`GH_TOKEN` env var (same endpoints `gh` wraps under the
   hood) — don't ask the user to install anything just to answer "why did
   CI fail."
2. Confirm this is a GitHub-hosted repo with Actions workflows
   (`.github/workflows/*.yml`) — if there are none, this skill doesn't
   apply.

## Scope

Default to the current branch. If it has an open PR, `gh pr checks`
gives the most direct pass/fail table per check; otherwise use
`gh run list --branch <branch> --limit 20 --json
databaseId,name,status,conclusion,headBranch,event,createdAt` and filter
to `conclusion == "failure"`. Accepts an optional scope argument for a
different branch, a specific run ID, or `all` for every workflow's most
recent run regardless of branch.

## Pulling the actual error, not the whole log

For each failing run, use `gh run view <id> --log-failed` — it returns
only the failed step's output, not the entire (often huge) log. Within
that, look for GitHub's own error annotations (`##[error]` lines) first;
they mark the actual failure point. Include a few lines of surrounding
context (the actual assertion, stack trace, or compiler error), not the
whole step output — a wall of build/setup noise around one real error
line isn't useful to show or to act on.

If `gh` isn't available, the REST API equivalent is
`GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs` for job/step
status, then `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` for
the raw log text (same filtering approach applies).

## Classifying each failure

- **Flaky / infra** — a transient network error, a runner timeout or
  OOM, an external service outage, a rate limit, or a test that's known
  to be nondeterministic. These don't need a code fix — recommend
  re-running the job (`gh run rerun <id> --failed`) rather than treating
  the symptom as a bug. Don't guess "flaky" just because a fix isn't
  obvious; only call it that when the error itself is infra-shaped
  (timeout, connection reset, "runner out of disk," a dependency
  registry 503, etc.), or the same job has intermittently passed on
  identical code before.
- **Real failure** — everything else: a test assertion that's actually
  wrong, a lint/type error, a build/compile failure, a missing
  dependency, a broken config. Classify by what kind it is, since that
  determines the fix.

## Fixing real failures, in batches

Reproduce the failure locally first, using the exact command the
workflow step runs (read the `run:` line from the relevant job in
`.github/workflows/*.yml`) — that feedback loop is much faster than
pushing and waiting for CI to re-run for every attempted fix. Only push
once the local repro is clean.

Don't try to fix every failing job across every workflow in one pass if
there are several unrelated ones. Batch by workflow or by root cause
(several jobs failing on the same underlying issue count as one batch);
fix, reproduce locally, then move to the next batch.

## Keeping TODO_TASKS.md current

Follow `skills/_shared/task-list.md` for the shared file, structure, and
cleanup convention. Specifics for this skill:

- Tag each item `[dsg-actions, <date>]` and include the run/job ID in the
  item text (e.g. `... (run 123456789, job "test")`).
- Group items under `CI — Flaky/Infra (re-run only)`, `CI — Test
  Failures`, `CI — Lint/Type Errors`, and `CI — Build Errors`.
- Cleanup pass: re-check whether the latest run for that branch/workflow
  now succeeds (`gh run list --branch <branch> --workflow <name> --limit
  1 --json conclusion`); if it's green, remove the item — that's a more
  direct signal than re-grepping code.

## Output

Report counts up front (failing runs found, how many classified
flaky/infra vs real, by category), then the same shape as `dsg-sonar`:
"N fixed this run, M flagged flaky (re-run recommended), K remaining in
`TODO_TASKS.md`."

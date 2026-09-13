# Finding format (shared convention)

Referenced by every `*-check` skill in this repo, so the reporting
convention only has to change in one place. This is not a skill itself —
it's a shared reference the `*-check` skills' Output sections point to.

## Standalone

When a `*-check` skill is invoked directly (not delegated), report
findings as a plain list, most important first: file:line, a one-sentence
summary of the problem, and a concrete suggested fix. Group by
sub-category if that helps readability; don't invent severity tiers
beyond what's needed to order the list.

## Delegated (called from another skill, e.g. an orchestrator like `dsg-pr-check`)

Return findings as data for the caller to fold into its own task list,
not as a formatted standalone report. Each finding needs:

- file:line
- one-sentence summary of the problem
- concrete suggested fix
- the category label the caller's own checklist uses for this check (e.g.
  `dsg-pr-check`'s "Test coverage gaps")

Don't print a `PASS`/`FAIL`/`N/A` verdict yourself when delegated — the
caller owns that decision (for example, `dsg-pr-check` reports `N/A`
itself for `dsg-changelog-check` when Release Drafter is present, rather
than the sub-skill deciding that).

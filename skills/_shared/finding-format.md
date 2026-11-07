# Finding format (shared convention)

Referenced by every `*-check` skill in this repo, so the reporting
convention only has to change in one place. This is not a skill itself —
it's a shared reference the `*-check` skills' Output sections point to.

## Forked runs: scope and arguments

Every `*-check` skill sets `context: fork`, `model: sonnet` and
`background: false` in its frontmatter. It runs in its own sub-agent on a
cheaper model, the caller waits for it, and only its final message comes
back. That sub-agent starts with no conversation history, so it decides
what to check from its arguments (appended to the skill as
`ARGUMENTS: ...`):

- **Delegated:** an orchestrator passes
  `delegated-from=<skill> base=<ref> category="<label>" docs=<paths>`,
  plus an optional `scope=<note>` (for example `scope=full-tree` for a
  release-time dependency audit).
  - Check `git diff <base>...HEAD` plus any uncommitted changes.
  - Read the listed standards docs first. Their conventions win over the
    skill's generic guidance.
  - Report in the Delegated format below, using the given `category`.
- **Standalone (no `delegated-from`):**
  - Work out the scope yourself: the current branch against `git
    merge-base HEAD origin/<default>`, plus any uncommitted changes. The
    default branch comes from `git symbolic-ref --short
    refs/remotes/origin/HEAD`, falling back to `main`.
  - Look for the project's standards docs (`CLAUDE.md`,
    `CONTRIBUTING.md`, or similar) yourself.
  - Report in the Standalone format.
- **Always:**
  - Stay read-only. A check never edits files or writes `TODO_TASKS.md`;
    the caller decides what to do with its findings.
  - End with the findings themselves as your final message, because
    that's all the caller receives. If there's nothing, say "No findings"
    and add one line on what was checked.

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

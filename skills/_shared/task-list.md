# Shared task-list convention (TODO_TASKS.md)

Used by every skill in this repo that turns findings into a worklist, so
they share one file and one cleanup routine instead of each spawning its
own. This is not a skill itself — it's a shared reference those skills'
Output sections point to.

## File

All such skills write to a single `TODO_TASKS.md` in the target repo's
root — never a separate file per skill. Before the first write, check
`.gitignore` for an entry covering `TODO_TASKS.md`; add one if missing —
it's a local working file, not something meant to be committed.

## Structure

Group items under category headings — the same category names the
calling skill's own checklist uses (e.g. `dsg-pr-check`'s "Test coverage
gaps", "Security"). Reuse an existing heading from a prior run instead of
creating a duplicate one. Each item:

```markdown
- [ ] <file:line> — <concrete action> (<why it matters>) [<skill-name>, <YYYY-MM-DD>, <severity>]
```

The trailing `[skill-name, date, severity]` tag records where, when, and
how bad the finding is — it's what makes the cleanup pass below possible
without a separate tracking file, and what a skill like `dsg-issue-todo` needs
to group items sensibly when turning them into GitHub Issues.

An item that has a GitHub issue carries ` → #<n>` at the end of its line
(added by `dsg-issue-todo`). It stays in the file, unchecked, so the
dedup rule below stops writer skills from re-adding it on their next
run. Cleanup step 1 still removes it once the finding no longer
reproduces.

```markdown
# TODO Tasks

## Test coverage gaps
- [ ] src/auth/session.py:42 — add a test for expired-token rejection (auth path, currently untested) [dsg-pr-check, 2026-09-12, medium]

## Security
- [ ] src/api/upload.py:18 — validate content-type before write (path traversal risk) [dsg-pr-check, 2026-09-12, critical]
```

## In progress

`TODO_TASKS.md` may also start with an `## In progress` section, directly
under the `# TODO Tasks` title: the plan, decisions made, and next step for
unfinished work, as short free-form notes rather than checklist items.
The `dsg-tasks-context` SessionStart hook loads that section (only that
section) into every new session, so work in flight survives `/clear`,
compaction, a devcontainer rebuild, or a switch between machines that
share the project's Claude data. Keep it current as the work changes,
and delete it once the work is done. It isn't a category: the cleanup
pass below doesn't touch it.

## Severity

Four tiers: `critical`, `high`, `medium`, `low`. Judge it by impact if left
unfixed (security exposure, data loss, broken functionality, breaking a
contract), never by how much effort the fix takes. Each writer skill's own
"Keeping TODO_TASKS.md current" section says how it maps its findings onto
these four tiers. If a finding's severity changes on a later run (e.g. a
re-classification), update the existing item's tag in place rather than
adding a second entry for it.

## Adding findings

Before adding an item, check whether an equivalent one (same file:line,
same problem) already exists under that category, checked or not — don't
add a duplicate. If a finding recurs after being marked fixed, that means
it wasn't actually fixed: reopen the existing item (`- [x]` → `- [ ]`,
update its date tag) rather than adding a second copy.

## Cleanup — run every time, before adding new findings, even on a run
that finds nothing new

1. **Re-verify existing items in categories this run just checked.** If a
   check that ran this time no longer reproduces a finding already listed
   under its category (checked or not), remove that item outright — it's
   fixed, and a clean pass is exactly when there's evidence of that. Don't
   just leave resolved items sitting there checked indefinitely.
2. **Prune old checked items.** Remove any `- [x]` item more than 14
   days past its `(done YYYY-MM-DD)` date (fall back to the tag date if
   it has none), regardless of category or which skill added it.
   A checked item is a short breadcrumb for "recently resolved," not a
   permanent log — git history is the permanent record.
3. Remove any category heading left with no items after this pass.

## Marking items done

Work through unchecked items one at a time (with the user, or in a
follow-up turn): fix it, re-run the specific check that flagged it to
confirm, then mark it `- [x]` — keep the original tag and append
` (done YYYY-MM-DD)` with today's date, so a long-standing item fixed
today isn't pruned on the next run. It gets pruned automatically once
that date is more than 14 days old, per above.

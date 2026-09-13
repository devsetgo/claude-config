---
name: dsg-issue-todo
description: Convert TODO_TASKS.md entries into GitHub Issues via the gh CLI, grouped by category and severity (e.g. every Sonar code-smell fix as one issue, a single critical security item as its own) — always shows the proposed title/body/grouping/labels and gets explicit confirmation before creating anything. Use to turn an accumulated local worklist into trackable GitHub Issues. For turning an in-progress plan/design discussion (not yet in TODO_TASKS.md) into an issue, use `dsg-issue-new` instead.
---

# TODO Backlog → GitHub Issues

Takes the shared `TODO_TASKS.md` worklist (see `skills/_shared/task-list.md`)
and turns unchecked items into GitHub Issues, grouped sensibly instead of
one issue per line or one giant issue for everything. Creating an issue is
visible to the whole team, so nothing gets created without the user seeing
the exact title, body, grouping, and labels first.

## Before running

1. Confirm `TODO_TASKS.md` exists at the repo root with at least one
   unchecked (`- [ ]`) item. If it's missing or empty, say so — nothing to
   convert.
2. Confirm `gh` is installed and authenticated (`gh auth status`) and that
   `gh repo view` resolves — this skill is GitHub-specific by design
   (GitHub Issues), so a repo without a GitHub remote doesn't apply.
3. Read `gh label list --json name -q '.[].name'` once up front; reuse
   that list for the label matching below rather than querying per issue.

## Scope

Default: every unchecked item in the file. Accepts an optional filter
argument: a category heading (e.g. `Sonar — Bugs`), a severity
(`critical`/`high`/`medium`/`low`), or a source-skill tag (e.g. `sonar`,
`dsg-actions`). Ask the user to confirm the filter only if the argument is
ambiguous against the headings actually present in the file.

## Grouping

Every item in `TODO_TASKS.md` carries a category heading and a
`[<skill>, <date>, <severity>]` tag per `skills/_shared/task-list.md`.
Treat items with no severity tag (written before that convention existed)
as `medium` and say so in the plan, rather than guessing higher or lower.

Never mix categories in one issue — a heading already represents one
coherent kind of work. Within a category, default to:

- **`critical`/`high` severity → its own issue.** High-impact items
  deserve individual visibility and shouldn't get buried as one checkbox
  in a longer list.
- **`medium`/`low` severity → batched into one issue per category**, body
  formatted as a checklist (one checkbox per source item, each keeping its
  `file:line` and original tag for traceability).

This is a default, not a rule — always show the proposed grouping and let
the user split a batch, merge two proposed issues, move an item to a
different issue, or change severity before anything is created.

## Dedup against existing issues

Before finalizing the plan, for each candidate item search open issues for
a reference to its `file:line` (`gh issue list --state open --search
"<file:line> in:body"`). If a match exists, drop that item from the plan
and note "already tracked in #<N>" instead of proposing a duplicate.

## Drafting each proposed issue

- **Title** — concise, action-oriented, no severity/category prefix (that
  belongs in labels): e.g. "Add test for expired-token rejection", not
  "[medium] fix thing".
- **Body** — for a single-item issue, the item's own action + why-it-
  matters. For a batched issue, a markdown checklist, one line per item in
  the same `- [ ] file:line — action (why)` shape as the source file, plus
  each item's original `[skill, date, severity]` tag for traceability. End
  the body with a short footer noting it was generated from the local
  `TODO_TASKS.md` worklist via `dsg-issue-todo`.
- **Labels** — match severity and category against the label list read in
  step 3 (case-insensitive exact or clear substring match, e.g. a label
  literally named `critical` or `priority: critical`). Only ever attach
  labels that already exist. If nothing matches, say so in the plan and
  ask whether to create one, use a different existing label instead, or
  leave the issue unlabeled — never create a label without that explicit
  go-ahead, since new labels are repo-wide and visible to everyone.

## Confirmation (mandatory, every time)

Present the full plan before creating anything: for each proposed issue,
its title, body, labels, and which source lines feed it, plus any dedup
skips and any label decisions still open. Wait for explicit confirmation
(or edits) — this step never gets skipped, including on repeat
invocations in the same session.

## Creating the issues

Once confirmed, create each one with `gh issue create --title "..."
--body-file <path> --label "..."` (write the body to a scratchpad file
first rather than fighting shell-quoting on a multi-line `--body`). Create
them one at a time so a failure partway through doesn't leave the plan's
state ambiguous — report each success with its issue number/URL as it
happens.

After an issue is created successfully, remove the items it covers from
`TODO_TASKS.md` — they're now tracked on GitHub, and leaving them would
either duplicate tracking or get miscounted as still-local by the next
`skills/_shared/task-list.md` cleanup pass. Don't mark them `- [x]`
(that means "fixed," which isn't true yet); just delete the lines, and
remove the category heading if that was its last item. Leave items whose
issue creation failed untouched, still unchecked, in the file.

## Output

Report: items considered, items skipped as dedup, issues proposed vs.
confirmed vs. created, then each created issue's number/URL grouped the
same way as the plan. Confirm how many `TODO_TASKS.md` lines were removed.

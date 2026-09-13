---
name: dsg-issue-new
description: Turn a plan already worked out in this conversation — a new feature, enhancement, or bug fix — into a single titled, labeled GitHub Issue with a detailed description drawn from that plan, via the gh CLI, always confirmed before creating. Use right after planning out work you want tracked on GitHub instead of only in conversation. For converting existing TODO_TASKS.md backlog items instead, use `dsg-issue-todo`.
---

# Plan → GitHub Issue

Captures a plan already worked out in conversation — a new feature,
enhancement, or bug fix, whether it came from Plan mode, a design
discussion, or a bug the user just described and diagnosed — as a single
GitHub Issue: a real title, a detailed description, and labels, with the
same drafting and confirmation discipline as `dsg-issue-todo`. Unlike that
skill, there's no local worklist file to read from — the plan already
exists in the conversation, so draft directly from that instead of asking
the user to restate it.

## Before running

1. Confirm `gh` is installed and authenticated (`gh auth status`) and that
   `gh repo view` resolves — same GitHub-specific prerequisite as
   `dsg-issue-todo`.
2. Read `gh label list --json name -q '.[].name'` once up front; reuse
   that list for the label matching below.
3. Confirm there's an actual plan to draw from — a completed planning
   discussion, a Plan-mode plan, or a clearly described bug with a
   diagnosed cause. If asked to do this before any such plan exists (e.g.
   "make an issue" with nothing discussed yet), ask the user to describe
   the work first rather than inventing content to fill the issue.

## Drafting

- **Type** — decide bug vs. feature/enhancement from the plan's own
  shape (a bug restores previously-working behavior; a feature/
  enhancement adds new behavior). This drives both the label choice and
  how the body gets framed: bug → symptom + root cause + fix; feature →
  motivation + approach.
- **Title** — short and specific enough to identify this issue among
  others without opening it, drawn from the plan's actual objective —
  not a vague restatement like "implement plan."
- **Body** — a detailed description assembled only from what was
  actually discussed, structured proportionate to what exists:
  - **Summary** — one or two sentences: what this is and why it matters.
  - **Problem / motivation** — for a bug: the observed symptom and root
    cause, if diagnosed; for a feature: the gap or need driving it.
  - **Proposed approach** — the plan's actual design/implementation
    approach, key files or components it touches, and any explicitly
    decided trade-offs.
  - **Out of scope** — only if the discussion explicitly ruled something
    out.
  - **Acceptance criteria / testing notes** — only if discussed.

  Omit any section with nothing behind it rather than padding it with
  boilerplate — a short issue beats a templated one with empty-feeling
  sections.
- **Labels** — match the bug/feature classification and anything else
  discussed (priority, affected area) against the label list from step 2
  (case-insensitive exact or clear substring match on existing names).
  Only ever attach labels that already exist. If nothing matches a label
  that seems warranted, say so and ask whether to create one, use a
  different existing label instead, or leave it unlabeled — never create
  a label without that explicit go-ahead, since new labels are repo-wide
  and visible to everyone, same rule as `dsg-issue-todo`.

## Splitting large plans

If the plan clearly bundles multiple independent chunks of work (a big
feature with a few genuinely separable pieces), say so and ask whether the
user wants one issue for the whole plan or several linked issues instead —
don't split unasked, and don't force an obviously multi-part plan into one
issue either. Default to a single issue when it's a close call; splitting
is the exception, not the default.

## Confirmation (mandatory, every time)

Show the drafted title, full body, and labels before creating anything,
exactly as they'd appear on GitHub. Wait for explicit confirmation or
edits — never create on the first pass, even when the plan itself was
already agreed with the user earlier in the conversation. Agreeing to the
plan is not the same as agreeing to this specific issue text.

## Creating the issue

Once confirmed, write the body to a scratchpad file and run `gh issue
create --title "..." --body-file <path> --label "..."` (a scratch file
avoids fighting shell-quoting on a multi-line `--body`). Report the
resulting issue number and URL.

If pieces of this plan later need tracking as a local worklist while
implementing (e.g. sub-tasks surfaced mid-build), that's a separate
concern — `dsg-issue-todo` converts `TODO_TASKS.md` entries to issues;
this skill only creates the one plan-level issue.

## Output

Show the final drafted title/body/labels as confirmed, then the created
issue's number and URL.

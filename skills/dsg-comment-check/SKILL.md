---
name: dsg-comment-check
description: Spot-check new/changed functions for missing "why" comments on non-obvious logic — workarounds, invariants, hidden constraints — not "what" comments. Use standalone or as part of dsg-pr-check.
---

# Comment Coverage Check

Find changed functions that have tricky logic and zero explanation — not
functions that are merely uncommented.

## Steps

1. Walk the diff's new/changed functions.
2. For each, judge whether the logic has a non-obvious *why*: a workaround
   for a specific bug or API quirk, a subtle invariant the code depends on,
   a hidden constraint, or something whose behavior would surprise a
   reader seeing it cold.
3. If such logic exists and there's no comment explaining it, flag it.
4. Do not flag:
   - self-explanatory code, however uncommented
   - comments that restate *what* the code does rather than *why* (these
     are a separate style nit, not a coverage gap — mention only if asked)
   - existing code outside the diff

## Output

A list of flagged functions, each with: file:line, a one-line description
of the non-obvious thing that needs explaining, and (if easy to infer) a
suggested comment. See `skills/_shared/finding-format.md` for the
standalone-vs-delegated reporting convention.

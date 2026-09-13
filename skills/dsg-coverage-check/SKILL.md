---
name: dsg-coverage-check
description: Identify test coverage gaps in changed code (not just overall percentage), ruling out dead code and unreachable branches first, prioritized by risk. Use standalone or as part of dsg-pr-check.
---

# Test Coverage Check

Find meaningful test coverage gaps in the *changed* code — not a general
crusade for 100% coverage.

## Steps

1. Run the project's test suite with coverage enabled (e.g. `pytest --cov`,
   `go test -cover`, `jest --coverage`, or whatever this project's own test
   command is — check `CONTRIBUTING.md`/`CLAUDE.md`/CI config before
   guessing).
2. Diff coverage against the changed files/lines only. A drop in overall
   percentage is not itself a finding; an uncovered branch in a changed
   function is.
3. Before flagging a gap, rule it out:
   - **Dead code** — grep for real callers. If nothing calls it, recommend
     deletion instead of a test.
   - **Unreachable in this environment** — a branch gated by config/driver
     that can't fire locally (e.g. a cloud-only code path) isn't a gap,
     it's untestable here; note it as such rather than flagging it.
4. Prioritize remaining gaps by risk, not line count: auth, data writes,
   money/security-adjacent logic, and anything touching external state
   outweigh a large but low-stakes helper function.

## Output

A list of gaps, each with: file:line, what's untested, why it matters
(risk category), and a concrete suggestion (what test to add, or "delete —
unused" for dead code). See `skills/_shared/finding-format.md` for the
standalone-vs-delegated reporting convention.

---
name: dsg-error-check
description: Check new/changed code for swallowed exceptions, inconsistent logging, and error responses that leak internals. Use standalone or as part of dsg-pr-check.
---

# Error Handling Check

Find places where the diff hides or mishandles failures — not a demand for
error handling everywhere.

## Steps

1. Walk the diff for error-handling constructs: `try`/`except`, `try`/
   `catch`, error-return patterns (Go-style `if err != nil`, Result/Either
   types), and API error responses.
2. Flag:
   - **swallowed errors** — empty catch/except blocks, `except: pass`,
     `catch (e) {}`, or a caught error that's neither logged, re-raised,
     nor handled with a visible fallback
   - **overly broad catches** — a bare `except:`, `catch (Exception e)`,
     or equivalent at a point where only a specific failure is expected,
     silently absorbing unrelated bugs along with the intended case
   - **inconsistent logging** — similar error paths nearby where some log
     with useful context (stack trace, request/correlation id) and others
     don't, suggesting an oversight rather than a deliberate choice
   - **leaked internals** — error messages/responses exposed to external
     callers (API responses, user-facing UI, client logs) that include
     stack traces, SQL, file paths, or other implementation detail
3. Don't flag intentional, documented pass-through (a custom exception
   type, a clear comment explaining why an error is ignored, or a
   deliberate fallback path).

## Output

A list of findings, each with: file:line, what's wrong, and a concrete
fix (log with context, narrow the catch, add a re-raise, sanitize the
response). See `skills/_shared/finding-format.md` for the
standalone-vs-delegated reporting convention.

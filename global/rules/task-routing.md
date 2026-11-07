# Task routing

Decide where work runs before starting it. The cost driver is context
lifetime: anything in the main context is re-sent on every later turn,
while a sub-agent's tokens are paid once and only its summary comes back.
This rule authorizes delegation in the cases below without being asked.

**Inline (main session)** — the default. Use when any apply:
- Debugging or investigation that needs reasoning as you go
- Design or approach still open
- Changes coupled to context already loaded, or a small targeted edit

**Fresh sub-agent on a cheaper model** (`sonnet`; `haiku` for purely
mechanical edits) when the work produces output you won't need again or
splits into independent pieces:
- Log/CI triage, test runs, broad searches across many files
- Bulk or repetitive edits, scaffolding, migrations from a written spec
- Independent review passes; run independent pieces in parallel

**Fork** (inherits the conversation, same model) for a side-task that
needs the context so far but whose tool output shouldn't stay in it.

When delegating, decide the approach yourself first and write a spec the
sub-agent can follow without design decisions: exact files, what to
change, a pattern or example to copy, constraints, and how to verify.
Review the diffs and run the verification yourself before reporting done.

If unsure, do it inline.

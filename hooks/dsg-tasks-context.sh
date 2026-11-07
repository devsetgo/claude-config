#!/usr/bin/env bash
# SessionStart hook (registered by install.sh): loads the "## In progress"
# section of the project's TODO_TASKS.md into the session's context, so
# in-progress work carries across sessions, devcontainer rebuilds, and
# machines that share the project's Claude data. Claude Code adds a
# SessionStart hook's plain-text stdout to the model's context.
#
# Only the "## In progress" section is loaded (up to the next "# " or "## "
# heading, capped at 80 lines), so a large backlog doesn't cost context
# every session.
#
# Silent when there's nothing to load: no TODO_TASKS.md, no such section,
# or an empty one. Never fails or blocks a session.
# Set DSG_TASKS_NO_CONTEXT=1 to disable entirely.

[ "${DSG_TASKS_NO_CONTEXT:-}" = 1 ] && exit 0

file="${CLAUDE_PROJECT_DIR:-$PWD}/TODO_TASKS.md"
[ -f "$file" ] && [ -r "$file" ] || exit 0

# Portable awk (no IGNORECASE): match the heading with tolower().
awk '
  function flush(   first, last, i, n) {
    first = 0; last = 0
    for (i = 1; i <= count; i++)
      if (body[i] ~ /[^ \t\r]/) { if (!first) first = i; last = i }
    if (!first) return
    print "In-progress work from TODO_TASKS.md (loaded at session start by the dsg-tasks-context hook; keep it current as the work changes):"
    n = last - first + 1
    for (i = first; i <= last && i < first + 80; i++) print body[i]
    if (n > 80) print "… (truncated; see TODO_TASKS.md for the rest)"
  }
  inside && (/^# / || /^## /) { exit }
  !inside && tolower($0) ~ /^## +in progress[ \t\r]*$/ { inside = 1; next }
  inside { body[++count] = $0 }
  END { flush() }
' "$file" 2>/dev/null

exit 0

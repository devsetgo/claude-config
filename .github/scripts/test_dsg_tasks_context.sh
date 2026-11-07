#!/usr/bin/env bash
# Exercises hooks/dsg-tasks-context.sh against throwaway project dirs: it must
# print only the "## In progress" section of TODO_TASKS.md (trimmed, capped),
# stay silent when there's nothing to load, and never fail.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
unset DSG_TASKS_NO_CONTEXT
HOOK="$REPO_DIR/hooks/dsg-tasks-context.sh"
HEADER='In-progress work from TODO_TASKS.md (loaded at session start by the dsg-tasks-context hook; keep it current as the work changes):'
TRUNC='… (truncated; see TODO_TASKS.md for the rest)'

# Each case gets a fresh project dir; run <dir> captures hook output in $out.
newdir() { rm -rf "$WORK/p"; mkdir -p "$WORK/p"; }
run() { out="$(CLAUDE_PROJECT_DIR="$WORK/p" "$HOOK")" || fail "non-zero exit"; }

echo "== no TODO_TASKS.md: silent"
newdir
run
[ -z "$out" ] || fail "output without a file"

echo "== no In progress section: silent"
newdir
printf '# Tasks\n\n## Backlog\n- a\n' > "$WORK/p/TODO_TASKS.md"
run
[ -z "$out" ] || fail "output without a section"

echo "== section with content: header, subheading, stops at next ## heading"
newdir
cat > "$WORK/p/TODO_TASKS.md" <<'MD'
# Title

## In progress
- doing a
### Sub
- sub line

## Other
- other line
MD
run
[ "$(printf '%s\n' "$out" | head -n1)" = "$HEADER" ] || fail "bad header"
grep -qx -- '- doing a' <<<"$out" || fail "missing content"
grep -qx -- '### Sub' <<<"$out" || fail "missing subheading"
grep -qx -- '- sub line' <<<"$out" || fail "missing subheading content"
! grep -q 'Other' <<<"$out" || fail "included next section heading"
! grep -q 'other line' <<<"$out" || fail "included next section body"
! grep -q 'Title' <<<"$out" || fail "included level-1 title"

echo "== only blank lines: silent"
newdir
printf '## In progress\n\n   \n\t\n## Other\n- x\n' > "$WORK/p/TODO_TASKS.md"
run
[ -z "$out" ] || fail "output for empty section"

echo "== heading variants"
newdir
printf '##  In Progress  \n- spaced\n' > "$WORK/p/TODO_TASKS.md"
run
grep -qx -- '- spaced' <<<"$out" || fail "spaced/cased heading didn't match"
newdir
printf '### In progress\n- nope\n' > "$WORK/p/TODO_TASKS.md"
run
[ -z "$out" ] || fail "level-3 heading matched"
newdir
printf '## In progress work\n- nope\n' > "$WORK/p/TODO_TASKS.md"
run
[ -z "$out" ] || fail "'In progress work' heading matched"

echo "== leading/trailing blank lines trimmed"
newdir
printf '## In progress\n\n\nfirst\n\nlast\n\n\n## Other\n' > "$WORK/p/TODO_TASKS.md"
run
[ "$(printf '%s\n' "$out" | sed -n 2p)" = first ] || fail "leading blanks not trimmed"
[ "$(printf '%s\n' "$out" | tail -n1)" = last ] || fail "trailing blanks not trimmed"

echo "== truncation at 80 body lines"
newdir
{ echo '## In progress'; seq -f 'line %g' 100; } > "$WORK/p/TODO_TASKS.md"
run
[ "$(printf '%s\n' "$out" | wc -l)" -eq 82 ] || fail "expected 82 lines, got $(printf '%s\n' "$out" | wc -l)"
[ "$(printf '%s\n' "$out" | sed -n 81p)" = "line 80" ] || fail "80th body line wrong"
[ "$(printf '%s\n' "$out" | tail -n1)" = "$TRUNC" ] || fail "missing truncation line"

echo "== DSG_TASKS_NO_CONTEXT=1: silent"
newdir
printf '## In progress\n- a\n' > "$WORK/p/TODO_TASKS.md"
out="$(DSG_TASKS_NO_CONTEXT=1 CLAUDE_PROJECT_DIR="$WORK/p" "$HOOK")" || fail "non-zero exit"
[ -z "$out" ] || fail "output while disabled"

echo "== CLAUDE_PROJECT_DIR unset: reads from the current directory"
out="$(cd "$WORK/p" && env -u CLAUDE_PROJECT_DIR "$HOOK")" || fail "non-zero exit"
grep -qx -- '- a' <<<"$out" || fail "didn't read from cwd"

echo "== unreadable file: silent, exit 0"
if [ "$(id -u)" = 0 ]; then
  echo "   (skipped: running as root can read it anyway)"
else
  chmod 000 "$WORK/p/TODO_TASKS.md"
  run
  [ -z "$out" ] || fail "output for unreadable file"
fi

echo "dsg-tasks-context hook tests OK"

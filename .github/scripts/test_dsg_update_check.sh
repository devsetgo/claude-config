#!/usr/bin/env bash
# Exercises hooks/dsg-update-check.sh against a throwaway origin
# and clone: it must report "behind" only on the default branch, never
# fail or block, and refresh refs with a background fetch when stale.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset DSG_UPDATE_NO_CHECK DSG_UPDATE_CHECK_HOURS
g() { git -C "$1" "${@:2}" -q; }

git init -q --bare -b main "$WORK/origin.git"
git clone -q "$WORK/origin.git" "$WORK/seed" 2>/dev/null
g "$WORK/seed" commit --allow-empty -m one
g "$WORK/seed" push origin main
git clone -q "$WORK/origin.git" "$WORK/clone"
mkdir -p "$WORK/clone/hooks"
cp "$REPO_DIR/hooks/dsg-update-check.sh" "$WORK/clone/hooks/"
HOOK="$WORK/clone/hooks/dsg-update-check.sh"
STAMP="$WORK/clone/.git/dsg-update-last-fetch"

new_upstream_commit() {
  g "$WORK/seed" commit --allow-empty -m "$1"
  g "$WORK/seed" push origin main
}

echo "== up to date: silent"
touch "$STAMP"
[ -z "$("$HOOK")" ] || fail "output while up to date"

echo "== behind (refs already fetched): reports, valid JSON"
new_upstream_commit two
g "$WORK/clone" fetch origin
out="$("$HOOK")"
python3 - "$out" <<'PY' || fail "bad output: $out"
import json, sys
d = json.loads(sys.argv[1])
assert "1 commit behind origin/main" in d["systemMessage"], d
assert d["hookSpecificOutput"]["hookEventName"] == "SessionStart"
assert "dsg-update" in d["hookSpecificOutput"]["additionalContext"]
PY

echo "== disabled via DSG_UPDATE_NO_CHECK=1: silent"
[ -z "$(DSG_UPDATE_NO_CHECK=1 "$HOOK")" ] || fail "output while disabled"

echo "== on a non-default branch: silent"
g "$WORK/clone" checkout -b dev
[ -z "$("$HOOK")" ] || fail "output on non-default branch"
g "$WORK/clone" checkout main

echo "== stale stamp: background fetch refreshes refs"
new_upstream_commit three
rm -f "$STAMP"
"$HOOK" >/dev/null
[ -f "$STAMP" ] || fail "stamp not written"
want="$(git -C "$WORK/seed" rev-parse HEAD)"
for _ in $(seq 50); do
  [ "$(git -C "$WORK/clone" rev-parse origin/main)" = "$want" ] && break
  sleep 0.2
done
[ "$(git -C "$WORK/clone" rev-parse origin/main)" = "$want" ] || fail "background fetch didn't update origin/main"
"$HOOK" | grep -q "2 commits behind" || fail "didn't report 2 commits after fetch"

echo "== fresh stamp: no fetch"
new_upstream_commit four
"$HOOK" >/dev/null
sleep 1
[ "$(git -C "$WORK/clone" rev-parse origin/main)" = "$want" ] || fail "fetched despite fresh stamp"

echo "== unreachable remote: exits 0 without blocking"
git -C "$WORK/clone" remote set-url origin "$WORK/missing.git"
rm -f "$STAMP"
start=$SECONDS
"$HOOK" >/dev/null || fail "non-zero exit with unreachable remote"
[ $((SECONDS - start)) -le 2 ] || fail "hook blocked on an unreachable remote"

echo "== not a git repo: silent, exit 0"
mkdir -p "$WORK/plain/hooks"
cp "$HOOK" "$WORK/plain/hooks/"
[ -z "$(GIT_CEILING_DIRECTORIES="$WORK" "$WORK/plain/hooks/dsg-update-check.sh")" ] || fail "output outside a repo"

echo "dsg-update hook tests OK"

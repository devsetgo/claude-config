#!/usr/bin/env bash
# Exercises install.sh against throwaway HOMEs so a regression in the one
# script every devcontainer depends on fails CI instead of failing silently
# in a dotfiles log.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_link() { [ "$(readlink "$1")" = "$2" ] || fail "$1 does not point to $2"; }

# Run with only the variables a test sets, so the runner's own
# CLAUDE_CONFIG_DIR can't leak in.
run() { env -i PATH="$PATH" "$@"; }

echo "== fresh install, re-run, --check"
H="$WORK/fresh"; mkdir -p "$H"
run HOME="$H" "$REPO_DIR/install.sh"
expect_link "$H/.claude/skills" "$REPO_DIR/skills"
expect_link "$H/.claude/rules" "$REPO_DIR/global/rules"
run HOME="$H" "$REPO_DIR/install.sh"
run HOME="$H" "$REPO_DIR/install.sh" --check

echo "== --check fails on an empty config dir"
H="$WORK/empty"; mkdir -p "$H"
if run HOME="$H" "$REPO_DIR/install.sh" --check; then fail "--check passed with nothing installed"; fi
[ ! -e "$H/.claude" ] || fail "--check created files"

echo "== repoint after the repo moves"
H="$WORK/moved"; mkdir -p "$H"
cp -r "$REPO_DIR" "$WORK/old-clone"
run HOME="$H" "$WORK/old-clone/install.sh"
run HOME="$H" "$REPO_DIR/install.sh"
expect_link "$H/.claude/skills" "$REPO_DIR/skills"
expect_link "$H/.claude/rules" "$REPO_DIR/global/rules"

echo "== refuses a real directory, still links the rest"
H="$WORK/conflict"; mkdir -p "$H/.claude/skills"
touch "$H/.claude/skills/keep-me"
if run HOME="$H" "$REPO_DIR/install.sh"; then fail "install succeeded over a real directory"; fi
[ -f "$H/.claude/skills/keep-me" ] || fail "existing directory was modified"
expect_link "$H/.claude/rules" "$REPO_DIR/global/rules"

echo "== honors CLAUDE_CONFIG_DIR"
H="$WORK/cfg"; mkdir -p "$H"
run HOME="$H" CLAUDE_CONFIG_DIR="$H/custom" "$REPO_DIR/install.sh"
expect_link "$H/custom/skills" "$REPO_DIR/skills"
[ ! -e "$H/.claude" ] || fail "wrote to ~/.claude despite CLAUDE_CONFIG_DIR"

HOOK="$REPO_DIR/hooks/dsg-update-check.sh"
# Count SessionStart hook entries of ours, and the commands they run.
hook_cmds() {
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
for g in d.get("hooks", {}).get("SessionStart", []):
    for h in g.get("hooks", []):
        if "dsg-update-check.sh" in h.get("command", ""):
            print(h["command"])
' "$1"
}

echo "== registers the dsg-update hook once, idempotently"
H="$WORK/fresh"
[ "$(hook_cmds "$H/.claude/settings.json")" = "$HOOK" ] || fail "hook not registered with $HOOK"
before="$(cksum < "$H/.claude/settings.json")"
run HOME="$H" "$REPO_DIR/install.sh" >/dev/null
[ "$(cksum < "$H/.claude/settings.json")" = "$before" ] || fail "re-run rewrote settings.json"

echo "== preserves existing settings and hooks"
H="$WORK/settings"; mkdir -p "$H/.claude"
cat > "$H/.claude/settings.json" <<'JSON'
{"permissions": {"allow": ["Bash(ls)"]},
 "hooks": {"SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "echo mine"}]}]}}
JSON
run HOME="$H" "$REPO_DIR/install.sh" >/dev/null
python3 - "$H/.claude/settings.json" <<'PY' || fail "existing settings or hooks lost"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["permissions"]["allow"] == ["Bash(ls)"]
cmds = [h["command"] for g in d["hooks"]["SessionStart"] for h in g["hooks"]]
assert "echo mine" in cmds and len(cmds) == 2, cmds
PY

echo "== repoints the hook after the repo moves (no duplicate)"
H="$WORK/moved"
[ "$(hook_cmds "$H/.claude/settings.json")" = "$HOOK" ] || fail "hook not repointed to $HOOK"

echo "== leaves unparseable settings.json alone, still links"
H="$WORK/badjson"; mkdir -p "$H/.claude"
echo '{ not json' > "$H/.claude/settings.json"
run HOME="$H" "$REPO_DIR/install.sh" >/dev/null 2>&1 || fail "bad settings.json failed the install"
[ "$(cat "$H/.claude/settings.json")" = '{ not json' ] || fail "bad settings.json was modified"
expect_link "$H/.claude/skills" "$REPO_DIR/skills"

echo "== DSG_UPDATE_NO_CHECK=1 removes the hook"
H="$WORK/fresh"
run HOME="$H" DSG_UPDATE_NO_CHECK=1 "$REPO_DIR/install.sh" >/dev/null
[ -z "$(hook_cmds "$H/.claude/settings.json")" ] || fail "hook not removed"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "hooks" not in d, d' \
  "$H/.claude/settings.json" || fail "empty hooks block left behind"

echo "install.sh tests OK"

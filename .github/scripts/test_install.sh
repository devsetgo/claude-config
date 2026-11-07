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
TASKS_HOOK="$REPO_DIR/hooks/dsg-tasks-context.sh"
# Print "matcher|command" for each SessionStart entry running SCRIPT_NAME.
hook_cmds() {
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
for g in d.get("hooks", {}).get("SessionStart", []):
    for h in g.get("hooks", []):
        if sys.argv[2] in h.get("command", ""):
            print(g.get("matcher", "") + "|" + h["command"])
' "$1" "${2:-dsg-update-check.sh}"
}

echo "== registers both hooks once, idempotently"
H="$WORK/fresh"
[ "$(hook_cmds "$H/.claude/settings.json")" = "startup|$HOOK" ] || fail "update hook not registered with $HOOK"
[ "$(hook_cmds "$H/.claude/settings.json" dsg-tasks-context.sh)" = "|$TASKS_HOOK" ] \
  || fail "tasks hook not registered for every session source"
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
assert "echo mine" in cmds and len(cmds) == 3, cmds
PY

echo "== repoints the hook after the repo moves (no duplicate)"
H="$WORK/moved"
[ "$(hook_cmds "$H/.claude/settings.json")" = "startup|$HOOK" ] || fail "hook not repointed to $HOOK"

echo "== leaves unparseable settings.json alone, still links"
H="$WORK/badjson"; mkdir -p "$H/.claude"
echo '{ not json' > "$H/.claude/settings.json"
run HOME="$H" "$REPO_DIR/install.sh" >/dev/null 2>&1 || fail "bad settings.json failed the install"
[ "$(cat "$H/.claude/settings.json")" = '{ not json' ] || fail "bad settings.json was modified"
expect_link "$H/.claude/skills" "$REPO_DIR/skills"

echo "== DSG_SHARED_CLAUDE_DIR=1 install changes nothing"
H="$WORK/fresh"
before="$(cksum < "$H/.claude/settings.json")"
run HOME="$H" DSG_SHARED_CLAUDE_DIR=1 "$WORK/old-clone/install.sh" >/dev/null || fail "shared-dir install failed"
expect_link "$H/.claude/skills" "$REPO_DIR/skills"
[ "$(cksum < "$H/.claude/settings.json")" = "$before" ] || fail "shared-dir install touched settings.json"
run HOME="$H" DSG_SHARED_CLAUDE_DIR=1 "$REPO_DIR/install.sh" --check >/dev/null || fail "--check skipped under DSG_SHARED_CLAUDE_DIR"

echo "== opt-out vars remove only their own hook"
run HOME="$H" DSG_UPDATE_NO_CHECK=1 "$REPO_DIR/install.sh" >/dev/null
[ -z "$(hook_cmds "$H/.claude/settings.json")" ] || fail "update hook not removed"
[ -n "$(hook_cmds "$H/.claude/settings.json" dsg-tasks-context.sh)" ] || fail "tasks hook removed too"
run HOME="$H" DSG_UPDATE_NO_CHECK=1 DSG_TASKS_NO_CONTEXT=1 "$REPO_DIR/install.sh" >/dev/null
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "hooks" not in d, d' \
  "$H/.claude/settings.json" || fail "empty hooks block left behind"

env_val() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("env", {}).get("CLAUDE_CODE_SUBAGENT_MODEL", ""))' "$1"
}

echo "== DSG_SUBAGENT_MODEL is opt-in, preserves other env, and survives re-runs"
H="$WORK/subagent"; mkdir -p "$H/.claude"
echo '{"env": {"FOO": "bar"}}' > "$H/.claude/settings.json"
run HOME="$H" "$REPO_DIR/install.sh" >/dev/null
[ -z "$(env_val "$H/.claude/settings.json")" ] || fail "set without DSG_SUBAGENT_MODEL"
run HOME="$H" DSG_SUBAGENT_MODEL=sonnet "$REPO_DIR/install.sh" >/dev/null
[ "$(env_val "$H/.claude/settings.json")" = sonnet ] || fail "not set to sonnet"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["env"]["FOO"] == "bar"' \
  "$H/.claude/settings.json" || fail "other env entries lost"
run HOME="$H" DSG_SUBAGENT_MODEL=sonnet "$REPO_DIR/install.sh" --check >/dev/null 2>"$WORK/check.err"
! grep -q CLAUDE_CODE_SUBAGENT_MODEL "$WORK/check.err" || fail "--check flagged a correct value"
run HOME="$H" "$REPO_DIR/install.sh" >/dev/null
[ "$(env_val "$H/.claude/settings.json")" = sonnet ] || fail "re-run without the variable undid it"

echo "== DSG_SUBAGENT_MODEL: rejects odd values, unset removes only that key"
run HOME="$H" DSG_SUBAGENT_MODEL='so"nnet' "$REPO_DIR/install.sh" >/dev/null 2>&1
[ "$(env_val "$H/.claude/settings.json")" = sonnet ] || fail "invalid value was written"
run HOME="$H" DSG_SUBAGENT_MODEL=unset "$REPO_DIR/install.sh" >/dev/null
[ -z "$(env_val "$H/.claude/settings.json")" ] || fail "unset didn't remove it"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["env"] == {"FOO": "bar"}' \
  "$H/.claude/settings.json" || fail "unset touched other env entries"

echo "install.sh tests OK"

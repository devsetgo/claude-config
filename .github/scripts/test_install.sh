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

echo "install.sh tests OK"

#!/usr/bin/env bash
# Wires this repo into where Claude Code looks for user-level config:
#   skills/        -> $CLAUDE_DIR/skills
#   global/rules/  -> $CLAUDE_DIR/rules   (instructions for every project)
# and registers two SessionStart hooks in $CLAUDE_DIR/settings.json:
#   hooks/dsg-update-check.sh   -- says when this clone is behind
#   hooks/dsg-tasks-context.sh  -- loads TODO_TASKS.md's "## In progress"
# Set DSG_UPDATE_NO_CHECK=1 / DSG_TASKS_NO_CONTEXT=1 when installing to
# leave one out (or remove it if it's already there).
# Run by VS Code's dotfiles feature after cloning this repo, or by hand on
# any machine. `install.sh --check` verifies everything without changing
# anything.
#
# Uses symlinks rather than copying files, so a later `git pull` in the
# cloned repo updates every devcontainer immediately with no reinstall.
#
# rules/ is linked instead of CLAUDE.md so each user's own
# ~/.claude/CLAUDE.md stays theirs -- user rules load at launch with the
# same priority, without forcing personal instructions into this repo.
#
# The Claude config directory isn't always ~/.claude -- Windows, WSL, and
# server setups can differ, and Claude Code's CLI respects CLAUDE_CONFIG_DIR
# to override it (e.g. for multiple profiles, or a shared/server location).
# Honor that instead of hardcoding the default.
set -euo pipefail

if [ -z "${HOME:-}" ]; then
  echo "error: \$HOME is not set -- can't determine where to install to." >&2
  exit 1
fi

MODE=install
case "${1:-}" in
  "") ;;
  --check) MODE=check ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Every link is attempted before exiting, so one conflict doesn't leave
# the rest silently uninstalled (dotfiles install logs are rarely read).
failures=0

link_managed() {
  local src="$1" dest="$2"

  if [ "$MODE" = check ]; then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ] && [ -e "$dest" ]; then
      echo "ok: $dest -> $src"
    else
      echo "missing or wrong: $dest (expected symlink to $src)" >&2
      failures=$((failures + 1))
    fi
    return
  fi

  if [ -L "$dest" ]; then
    # Already a symlink (e.g. repo re-cloned to a new path) -- repoint it.
    ln -sfn "$src" "$dest"
    echo "Updated symlink: $dest -> $src"
  elif [ -e "$dest" ]; then
    echo "error: $dest already exists and is not a symlink this repo manages." >&2
    echo "Move it aside yourself (it may hold files you don't want to lose), then re-run install.sh." >&2
    failures=$((failures + 1))
  else
    ln -s "$src" "$dest"
    echo "Linked $dest -> $src"
  fi
}

# A devcontainer that bind-mounts the host's Claude config dir (see the
# dsg-devcontainer skill) sets this, so a dotfiles run of install.sh inside
# the container doesn't repoint the host's links at the container's clone.
if [ "$MODE" = install ] && [ "${DSG_SHARED_CLAUDE_DIR:-}" = 1 ]; then
  echo "DSG_SHARED_CLAUDE_DIR=1: $CLAUDE_DIR is shared from the host -- run install.sh there instead."
  exit 0
fi

[ "$MODE" = install ] && mkdir -p "$CLAUDE_DIR"

link_managed "$REPO_DIR/skills" "$CLAUDE_DIR/skills"
link_managed "$REPO_DIR/global/rules" "$CLAUDE_DIR/rules"

# settings.json is per-user (permissions etc.), so hook entries are merged
# into it rather than linked. A failure here is a warning, not a failure:
# the links above are what make skills and rules work; the hooks are
# conveniences.
SETTINGS="$CLAUDE_DIR/settings.json"

# register_hook NAME SCRIPT OPT_OUT_VAR MATCHER
register_hook() {
  local name="$1" script="$REPO_DIR/hooks/$2" opt_out="$3" matcher="$4" mode=install rc
  [ "${!opt_out:-}" = 1 ] && mode=remove
  [ "$MODE" = check ] && mode=check

  if ! command -v python3 >/dev/null 2>&1; then
    echo "warning: python3 not found -- can't $mode the $name hook in $SETTINGS." >&2
    echo "Add it by hand: a SessionStart hook (matcher \"$matcher\") running $script" >&2
    return
  fi
  if python3 "$REPO_DIR/hooks/settings_hook.py" "$mode" "$SETTINGS" "$script" "$matcher"; then
    case "$mode" in
      install) echo "$name hook registered in $SETTINGS" ;;
      remove)  echo "$name hook not registered ($opt_out=1)" ;;
      check)   echo "ok: $name hook registered in $SETTINGS" ;;
    esac
    return
  fi
  rc=$?
  if [ "$mode" = check ] && [ "$rc" -eq 1 ]; then
    echo "warning: $name hook missing or stale in $SETTINGS (re-run install.sh)" >&2
  else
    echo "warning: couldn't $mode the $name hook in $SETTINGS (left unchanged)." >&2
  fi
}

register_hook dsg-update dsg-update-check.sh DSG_UPDATE_NO_CHECK startup
# Every session source, so in-progress work comes back after /clear and
# compaction too, not just on a fresh start.
register_hook dsg-tasks-context dsg-tasks-context.sh DSG_TASKS_NO_CONTEXT ""

if [ "$failures" -gt 0 ]; then
  echo "$failures link(s) not installed -- see errors above." >&2
  exit 1
fi

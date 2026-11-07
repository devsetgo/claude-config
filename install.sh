#!/usr/bin/env bash
# Wires this repo into where Claude Code looks for user-level config:
#   skills/        -> $CLAUDE_DIR/skills
#   global/rules/  -> $CLAUDE_DIR/rules   (instructions for every project)
# and registers hooks/dsg-update-check.sh as a SessionStart hook
# in $CLAUDE_DIR/settings.json, so sessions say when this clone is behind
# (set DSG_UPDATE_NO_CHECK=1 when installing to leave it out, or
# remove it if it's already there).
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

[ "$MODE" = install ] && mkdir -p "$CLAUDE_DIR"

link_managed "$REPO_DIR/skills" "$CLAUDE_DIR/skills"
link_managed "$REPO_DIR/global/rules" "$CLAUDE_DIR/rules"

# settings.json is per-user (permissions etc.), so the hook entry is merged
# into it rather than linked. A failure here is a warning, not a failure:
# the links above are what make skills and rules work; the dsg-update check
# is a convenience.
HOOK_SCRIPT="$REPO_DIR/hooks/dsg-update-check.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
hook_mode=install
[ "${DSG_UPDATE_NO_CHECK:-}" = 1 ] && hook_mode=remove
[ "$MODE" = check ] && hook_mode=check

if ! command -v python3 >/dev/null 2>&1; then
  echo "warning: python3 not found -- can't $hook_mode the dsg-update hook in $SETTINGS." >&2
  echo "Add it by hand: a SessionStart hook (matcher \"startup\") running $HOOK_SCRIPT" >&2
elif python3 "$REPO_DIR/hooks/settings_hook.py" "$hook_mode" "$SETTINGS" "$HOOK_SCRIPT"; then
  case "$hook_mode" in
    install) echo "dsg-update hook registered in $SETTINGS" ;;
    remove)  echo "dsg-update hook not registered (DSG_UPDATE_NO_CHECK=1)" ;;
    check)   echo "ok: dsg-update hook registered in $SETTINGS" ;;
  esac
else
  rc=$?
  if [ "$hook_mode" = check ] && [ "$rc" -eq 1 ]; then
    echo "warning: dsg-update hook missing or stale in $SETTINGS (re-run install.sh)" >&2
  else
    echo "warning: couldn't $hook_mode the dsg-update hook in $SETTINGS (left unchanged)." >&2
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures link(s) not installed -- see errors above." >&2
  exit 1
fi

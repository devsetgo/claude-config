#!/usr/bin/env bash
# Wires this repo into where Claude Code looks for user-level config:
#   skills/        -> $CLAUDE_DIR/skills
#   global/rules/  -> $CLAUDE_DIR/rules   (instructions for every project)
# Run by VS Code's dotfiles feature after cloning this repo, or by hand on
# any machine. `install.sh --check` verifies the links without changing
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

if [ "$failures" -gt 0 ]; then
  echo "$failures link(s) not installed -- see errors above." >&2
  exit 1
fi

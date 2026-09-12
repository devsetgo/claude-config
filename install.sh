#!/usr/bin/env bash
# Wires this repo's skills/ into where Claude Code looks for user-level
# skills (~/.claude/skills). Run by VS Code's dotfiles feature after
# cloning this repo, or by hand on any machine.
#
# Uses a symlink rather than copying files, so a later `git pull` in the
# cloned repo updates every devcontainer immediately with no reinstall.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
CLAUDE_DIR="$HOME/.claude"
SKILLS_LINK="$CLAUDE_DIR/skills"

mkdir -p "$CLAUDE_DIR"

if [ -L "$SKILLS_LINK" ]; then
  # Already a symlink (e.g. repo re-cloned to a new path) -- repoint it.
  ln -sfn "$SKILLS_SRC" "$SKILLS_LINK"
  echo "Updated symlink: $SKILLS_LINK -> $SKILLS_SRC"
elif [ -e "$SKILLS_LINK" ]; then
  echo "error: $SKILLS_LINK already exists and is not a symlink this repo manages." >&2
  echo "Move it aside yourself (it may hold skills you don't want to lose), then re-run install.sh." >&2
  exit 1
else
  ln -s "$SKILLS_SRC" "$SKILLS_LINK"
  echo "Linked $SKILLS_LINK -> $SKILLS_SRC"
fi

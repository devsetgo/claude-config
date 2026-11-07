#!/usr/bin/env bash
# SessionStart hook (registered by install.sh): tells the user when this
# claude-config clone is behind its remote, and suggests /dsg-update.
# Once releases exist, that means "a newer release is out" (see below).
#
# Never slows a session down or fails it: the "behind?" check only compares
# local refs, and the network fetch that refreshes them runs detached in the
# background at most once per DSG_UPDATE_CHECK_HOURS (default 24).
# So a new upstream commit is reported one session after the fetch sees it.
#
# Quiet unless the clone is on its default branch -- on any other branch
# someone is developing in it, and "you're behind main" is noise.
# Set DSG_UPDATE_NO_CHECK=1 to disable entirely.

[ "${DSG_UPDATE_NO_CHECK:-}" = 1 ] && exit 0

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || exit 0
git_() { git -C "$REPO_DIR" "$@" 2>/dev/null; }

GIT_DIR="$(git_ rev-parse --absolute-git-dir)" || exit 0
default="$(git_ symbolic-ref --short refs/remotes/origin/HEAD)"
default="${default#origin/}"
default="${default:-main}"
# The branch name goes into hand-built JSON below; refuse anything that
# would need escaping rather than emit broken output.
case "$default" in *[\"\\]*) exit 0 ;; esac
branch="$(git_ symbolic-ref --short HEAD)" || exit 0
[ "$branch" = "$default" ] || exit 0

hours="${DSG_UPDATE_CHECK_HOURS:-24}"
case "$hours" in ''|*[!0-9]*) hours=24 ;; esac
stamp="$GIT_DIR/dsg-update-last-fetch"
if [ -z "$(find "$stamp" -mmin -$((hours * 60)) 2>/dev/null)" ]; then
  # Stamp before fetching so parallel sessions don't each start a fetch.
  touch "$stamp" 2>/dev/null
  # All fds redirected so Claude Code doesn't wait on the background job.
  ( GIT_TERMINAL_PROMPT=0 git -C "$REPO_DIR" fetch --quiet origin "$default" ) \
    </dev/null >/dev/null 2>&1 &
fi

behind="$(git_ rev-list --count "HEAD..refs/remotes/origin/$default")" || exit 0
[ "${behind:-0}" -gt 0 ] 2>/dev/null || exit 0

# Releases (VERSION, bumped by the Release workflow) batch the notice: when
# the remote has a VERSION file, only a new release is announced, not every
# merge since yours. Without one (before the first release), fall back to
# counting commits.
remote_v="$(git_ show "refs/remotes/origin/$default:VERSION" | head -1)"
local_v="$(git_ show HEAD:VERSION | head -1)"
# Both go into hand-built JSON below; refuse anything that isn't a plain
# version string.
case "$remote_v$local_v" in *[!0-9A-Za-z.-]*) exit 0 ;; esac

if [ -n "$remote_v" ]; then
  [ "$remote_v" != "$local_v" ] || exit 0
  msg="claude-config $remote_v is available (you have ${local_v:-a pre-release clone}). Run /dsg-update to update."
else
  s=s; [ "$behind" -eq 1 ] && s=
  msg="claude-config is $behind commit$s behind origin/$default. Run /dsg-update to update."
fi
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s If the user asks to update claude-config, use the dsg-update skill; otherwise mention it once and do not run it unprompted."}}\n' \
  "$msg" "$msg"

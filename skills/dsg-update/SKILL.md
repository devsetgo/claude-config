---
name: dsg-update
description: Update this machine's claude-config clone (the repo these dsg-* skills and global rules come from) — find the clone through the installed skills symlink, show what's new upstream, fast-forward it only when that's safe, re-run install.sh, and verify with install.sh --check. Use when a session reports claude-config is behind, or when asked to update/upgrade the Claude config, skills, or global rules.
---

# Update claude-config

The skills, global rules, and dsg-update hook on this machine are
symlinks into one git clone, so updating it is a `git pull` plus a
re-run of `install.sh`. Re-running the installer picks up anything new it
manages (new links, a moved hook path). The clone may also be someone's
working copy, so never discard, stash, or rewrite anything in it.

## Steps

1. **Find the clone.** Resolve `${CLAUDE_CONFIG_DIR:-~/.claude}/skills`
   with `readlink -f`. The clone is the parent of that directory. Confirm
   it's a git repo with an `install.sh` at its root. If `skills` isn't a
   symlink, claude-config was never installed here. Say so and point to
   the Setup section of the clone's `README.md` (or the repo's), instead
   of guessing a location.

2. **Inspect before changing anything.**
   - Find the default branch from `git symbolic-ref --short
     refs/remotes/origin/HEAD`, falling back to `main`.
   - Get the current branch and `git status --porcelain`.
   - Run `git fetch origin`. If the fetch fails (offline, auth), report
     that and stop.
   - Count ahead/behind with `git rev-list --left-right --count
     HEAD...origin/<default>`.

3. **Decide.** Only fast-forward when every one of these holds:
   - It's on the default branch.
   - The working tree is clean.
   - It's behind, and not ahead.

   Otherwise stop and report, without "fixing" it:
   - **Uncommitted changes**: list them. Don't stash, commit, or discard.
   - **Another branch**: someone is developing here. Report how far that
     branch and the default branch are behind origin, and leave switching
     or merging to them.
   - **Ahead or diverged**: local commits exist. Never reset or rebase;
     say what's there.
   - **Up to date**: say so, then still run step 5's `--check`. An
     up-to-date clone with broken links is worth catching.

4. **Show what's coming, then update.**
   - Summarize `git log --oneline HEAD..origin/<default>`.
   - From `git diff --stat HEAD..origin/<default>`, call out skills
     added or removed under `skills/`, changes under `global/rules/`, and
     installer or hook changes.
   - Then run `git merge --ff-only origin/<default>`.

5. **Re-install and verify.** Run `./install.sh` from the clone, then
   `./install.sh --check`. Report any failures verbatim. A link conflict
   means a real file or directory is in the way; tell the user to move it
   aside themselves.
   - Inside a devcontainer that shares the host's config dir
     (`DSG_SHARED_CLAUDE_DIR=1`, see `dsg-devcontainer`), `install.sh` is
     deliberately a no-op. The pull still takes effect on both sides,
     because it's the same mounted clone. If the update changed
     `install.sh` or `hooks/`, tell the user to re-run `install.sh` from
     a host session.

6. **Tell the user to start a new session** if rules, skills, or the
   hook changed. Those load at session start, so the current session is
   still running the old versions.

## Output

A short report covering:
- Where the clone is.
- What changed (commit summary, plus notable skills, rules, or installer
  changes).
- Whether it updated, or exactly why not.
- The `install.sh --check` result.
- Whether a new session is needed.

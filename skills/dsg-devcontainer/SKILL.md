---
name: dsg-devcontainer
description: Set up a project's devcontainer to share the host's Claude Code data (memory, transcripts, settings, login, dsg-* skills and rules), so context survives container rebuilds and carries between WSL/the host and the container. Edits .devcontainer/devcontainer.json, optionally migrates data out of the current container first, and lists the acceptance checks. Use when Claude loses context after a devcontainer rebuild, or when the same project is worked on from both the host and a container.
---

# Share Claude Code data with a devcontainer

A rebuild deletes the container's own `~/.claude`. The host's and the
container's copies of a project also live at different paths (for
example `~/<repo>` versus `/workspaces/<repo>`), and Claude Code names
each project's memory and transcript folder after its path. So the two
never see each other's memory, even when they share a config dir.

The fix has two parts:
- **Bind-mount the host's config dir into the container at the same
  absolute path.** Symlinks and hook commands that `install.sh` wrote
  with host paths then resolve inside the container too.
- **Set `CLAUDE_CODE_PROJECT_DIR_NAME`** so the container writes this
  project's memory and transcripts straight into the host's folder.

Don't symlink one project folder to the other. Reading and saving
memory through a symlinked project folder runs into permission
prompts and blocked writes.

## Facts this relies on

These were tested on Claude Code 2.1.314 (Linux, `-p` mode), not just
taken from the docs:
- `CLAUDE_CODE_PROJECT_DIR_NAME` only applies when `CLAUDE_CONFIG_DIR`
  is also set. Claude Code reads it only from the environment it's
  launched in, never from a settings `env` block, and it needs v2.1.234
  or later.
- **It's silently ignored if the name is longer than 64 characters.**
  Claude Code falls back to the path-derived folder with no warning.
- With both set, the container saves memory and transcripts into the
  host's folder. The host session reads them, including topic files,
  with no permission prompts.
- **Setting `CLAUDE_CONFIG_DIR` also moves Claude Code's state file.**
  It reads `$CLAUDE_CONFIG_DIR/.claude.json` instead of `~/.claude.json`.
  That file holds onboarding, per-project state such as trust and
  allowed tools, and user-scope MCP servers. The host, running without
  the variable, keeps using `~/.claude.json`, so the two sides have
  separate state files. The container's survives rebuilds, because it
  sits in the mounted dir. Everything else is still shared.
- On Linux, login lives in `.credentials.json` inside the config dir, so
  it's shared. A contributor reported that on macOS, login lives in the
  Keychain instead: setting `CLAUDE_CONFIG_DIR` in a Mac host session
  printed "Not logged in" until they logged in again. That's untested
  here, and it only matters for a session run on a Mac host.

## Where this runs

Most steps run in a host session (WSL, or wherever VS Code opens the
folder from). Step 1 is the exception: it runs inside the existing
container, if there is one. If `REMOTE_CONTAINERS`, `CODESPACES`, or
`/.dockerenv` shows you're inside a container, only do step 1, then tell
the user to continue from a host session.

## Steps

1. **Migrate (only if the current container holds data worth keeping;
   otherwise skip).**
   - Inside the container, compute the container's key: the repo root's
     `pwd -P` with every non-alphanumeric character replaced by `-`.
   - Copy `~/.claude/projects/<container key>/.` into
     `<repo>/.git/claude-migrate/`. Use `.git/` because it's never
     committed and the host can see it.
   - Copying mid-conversation misses the rest of it; redo the copy just
     before the rebuild in step 5.

2. **Check the host side.**
   - Claude Code in the container must be v2.1.234 or later.
   - `${CLAUDE_CONFIG_DIR:-~/.claude}/skills` should be a symlink into a
     claude-config clone. If it isn't, run that clone's `install.sh`
     first. The clone's path is the directory above the symlink's
     target.
   - Compute the host key from the repo root: `git rev-parse
     --show-toplevel` (the directory sessions start in, normally the
     repo root), then `pwd -P` on that, then replace every
     non-alphanumeric character with `-`. It must match the folder name
     under `~/.claude/projects/`. If that folder exists, list it to
     confirm.
   - **If the key is over 64 characters**, `CLAUDE_CODE_PROJECT_DIR_NAME`
     won't work. Use the same-path workspace mount in step 3 instead.
   - **Seed the container's state file.** If `~/.claude/.claude.json`
     doesn't exist yet, run `cp -p ~/.claude.json ~/.claude/.claude.json`.
     The container then starts with the host's onboarding, user-scope MCP
     servers, and project state. Never overwrite an existing copy: it may
     already hold the container's own state. The copies drift apart after
     seeding, so a user-scope MCP server added later has to be added on
     both sides (a checked-in `.mcp.json` avoids that).

3. **Edit `.devcontainer/devcontainer.json`.** It's JSONC, so keep its
   comments and formatting, and merge with existing keys rather than
   replacing them. If an `initializeCommand` already exists, chain onto
   it. Below, `<clone>` is the claude-config clone's path, written as
   `${localEnv:HOME}/...` when it's under the home directory.

   ```jsonc
   "initializeCommand": "mkdir -p \"$HOME/.claude\"",
   "mounts": [
     "source=${localEnv:HOME}/.claude,target=${localEnv:HOME}/.claude,type=bind",
     "source=<clone>,target=<clone>,type=bind"
   ],
   "containerEnv": {
     "CLAUDE_CONFIG_DIR": "${localEnv:HOME}/.claude",
     "CLAUDE_CODE_PROJECT_DIR_NAME": "<host key>",
     "DSG_SHARED_CLAUDE_DIR": "1"
   }
   ```

   - `DSG_SHARED_CLAUDE_DIR=1` stops a dotfiles run of `install.sh`
     inside the container from re-pointing the shared links at the
     container's own clone.
   - **Ask whether this devcontainer config is shared with other
     contributors.** If it is, a literal host key is wrong for everyone
     else. Instead:
     - Have `initializeCommand` (which runs on the host) also write
       `CLAUDE_CODE_PROJECT_DIR_NAME=<key computed from pwd -P>` to
       `.devcontainer/.claude.env`, and gitignore that file.
     - Load it with `"runArgs": ["--env-file",
       "${localWorkspaceFolder}/.devcontainer/.claude.env"]`. For a
       docker-compose config, use `env_file:` in the compose service.
     - Also warn that every contributor then gets their own host
       `~/.claude` mounted in. They should agree to that first.
     - Mac-host contributors: tell them not to set `CLAUDE_CONFIG_DIR`
       on the host itself (see the Keychain note under Facts).
   - **Key over 64 characters:** leave out `CLAUDE_CODE_PROJECT_DIR_NAME`
     and mount the workspace at its host path, so both sides derive the
     same key on their own. Check first that nothing in the project
     assumes `/workspaces/...`:

     ```jsonc
     "workspaceMount": "source=${localWorkspaceFolder},target=${localWorkspaceFolder},type=bind",
     "workspaceFolder": "${localWorkspaceFolder}"
     ```

   - The container user must be able to write the mounted files. On
     Linux, devcontainers match the container user's UID to the host's
     by default (`updateRemoteUserUID`). Flag it if the config runs as
     `root` or turns that off. Files written as root end up root-owned
     on the host, and `git` in the container reports "dubious
     ownership" for the mounted clone.

4. **Merge migrated data (only if you did step 1).**
   - On the host, run `cp -rn` from `.git/claude-migrate/.` into
     `~/.claude/projects/<host key>/`. `-n` keeps the host's `MEMORY.md`
     if one exists; then add the container's index lines to it by hand,
     or those memories won't be listed.

5. **Rebuild.** If you did step 1, copy the container data out again
   first so the latest conversation comes along. Then merge the
   `*.jsonl` files as in step 4, and choose **Rebuild Container**.

## Acceptance checks

Hand these to the user to run after the rebuild. Run the write check
first, because it's the one most likely to fail.
- [ ] A memory saved in the container shows up in a host session, and
  vice versa.
- [ ] A new container session lists the project's memory and can read a
  topic file without a permission prompt.
- [ ] `/resume` in the container lists sessions from before the rebuild.
- [ ] The `dsg-*` skills are listed, and a new session shows the
  `## In progress` section of `TODO_TASKS.md` if one exists.
- [ ] Claude is still logged in after a second rebuild.
- [ ] If you use user-scope MCP servers, `claude mcp list` in the
  container shows the same ones as on the host, from the seeded
  `.claude.json`. Expect a one-time trust prompt, because the
  container's workspace path differs from the host's.
- [ ] `git status` shows no Claude data, and `.git/claude-migrate` is
  deleted once the checks pass.

## Known limits

- Don't run host and container sessions at the same time in one
  project; both write to the same files.
- Every project then shares the host's `~/.claude`, so settings, login,
  skills and rules are shared too. Memory stays per project.
- A session resumed on the other side still carries the other side's
  file paths in its history.
- Host and container keep separate `.claude.json` state files (see
  "Facts this relies on").

## Output

Report:
- The host key and its length.
- Which variant was applied: literal key, env file, or same-path
  workspace.
- The exact `devcontainer.json` changes.
- Whether migration was done (and any manual `MEMORY.md` merge needed),
  and whether `.claude.json` was seeded or already existed.
- The acceptance checklist.

Don't rebuild the container yourself. The user does that.

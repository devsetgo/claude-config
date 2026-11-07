#!/usr/bin/env python3
"""Add, remove, or check one of this repo's SessionStart hooks in a Claude Code settings.json.

Used by install.sh, once per hook script. settings.json holds each user's
own permissions and preferences, so it can't be symlinked like skills/ and
rules/ -- instead exactly one entry per script is merged in, identified by
the script's file name in its command, and everything else in the file is
left as it was.

usage: settings_hook.py {install|remove|check} SETTINGS_JSON HOOK_SCRIPT [MATCHER]
       MATCHER defaults to "startup"; "" registers it for every session
       source (startup, resume, clear, compact).
exit:  0 ok / already in the wanted state, 1 check failed,
       3 settings.json unreadable (left untouched)
"""
import json
import os
import shlex
import sys
import tempfile

def main():
    mode, path, script = sys.argv[1:4]
    matcher = sys.argv[4] if len(sys.argv) > 4 else "startup"
    marker = os.path.basename(script)

    def ours(hook):
        return marker in str(hook.get("command", ""))

    # Write through a symlinked settings.json (e.g. someone else's dotfiles)
    # rather than replacing the link with a regular file.
    path = os.path.realpath(path)
    command = shlex.quote(script)

    data = {}
    if os.path.exists(path):
        try:
            with open(path) as f:
                data = json.load(f)
        except (OSError, ValueError) as e:
            print(f"{path}: can't parse ({e}); not modifying it.", file=sys.stderr)
            return 3
        if not isinstance(data, dict):
            print(f"{path}: top level isn't a JSON object; not modifying it.", file=sys.stderr)
            return 3

    groups = data.get("hooks", {}).get("SessionStart", [])
    current = [(g.get("matcher", ""), h.get("command")) for g in groups for h in g.get("hooks", []) if ours(h)]

    installed = current == [(matcher, command)]
    if mode == "check":
        return 0 if installed else 1
    if mode == "install" and installed:
        return 0  # already right; leave the file byte-for-byte alone

    before = json.dumps(data, sort_keys=True)

    # Drop any previous entry of ours (e.g. from a clone at an old path),
    # and only the groups that held nothing but ours.
    kept = []
    for g in groups:
        if not any(ours(h) for h in g.get("hooks", [])):
            kept.append(g)
            continue
        g["hooks"] = [h for h in g["hooks"] if not ours(h)]
        if g["hooks"]:
            kept.append(g)

    if mode == "install":
        entry = {"hooks": [{"type": "command", "command": command, "timeout": 10}]}
        if matcher:
            entry = {"matcher": matcher, **entry}
        kept.append(entry)

    if kept:
        data.setdefault("hooks", {})["SessionStart"] = kept
    elif "SessionStart" in data.get("hooks", {}):
        del data["hooks"]["SessionStart"]
        if not data["hooks"]:
            del data["hooks"]

    if json.dumps(data, sort_keys=True) == before:
        return 0

    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".settings-")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        if os.path.exists(path):
            os.chmod(tmp, os.stat(path).st_mode & 0o777)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise
    return 0


if __name__ == "__main__":
    sys.exit(main())

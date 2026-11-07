#!/usr/bin/env python3
"""Set, unset, or check one variable in the `env` block of a Claude Code settings.json.

Used by install.sh for opt-in settings such as DSG_SUBAGENT_MODEL ->
CLAUDE_CODE_SUBAGENT_MODEL. Only the named key is touched; the rest of the
file, including other env entries, is left as it was.

usage: settings_env.py {set|unset|check} SETTINGS_JSON NAME [VALUE]
exit:  0 ok / already in the wanted state, 1 check failed,
       3 settings.json unreadable (left untouched)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from settings_hook import Unreadable, load, save  # noqa: E402


def main():
    mode, path, name = sys.argv[1:4]
    value = sys.argv[4] if len(sys.argv) > 4 else None
    try:
        path, data = load(path)
    except Unreadable as e:
        print(e, file=sys.stderr)
        return 3

    # Deliberately an alias of data["env"] (not a copy): the unset branch
    # below deletes through it.
    env = data.get("env", {})
    if mode == "check":
        return 0 if env.get(name) == value else 1

    before = json.dumps(data, sort_keys=True)
    if mode == "set":
        data.setdefault("env", {})[name] = value
    elif name in env:
        del env[name]
        if not env:
            del data["env"]
    if json.dumps(data, sort_keys=True) != before:
        save(path, data)
    return 0


if __name__ == "__main__":
    sys.exit(main())

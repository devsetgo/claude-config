---
name: dsg-secrets-check
description: Check for hardcoded secrets/config in the diff and drift between the env-example file and the env vars actually read by code. Use standalone or as part of dsg-pr-check.
context: fork
model: sonnet
background: false
---

# Secrets & Config Drift Check

A lighter-weight, config-focused complement to full secret scanning — the
goal here is specifically hardcoded config and env-var documentation
drift, not a replacement for `security-review`'s broader secret detection.

Forked run: first read `../_shared/finding-format.md` (relative to this
skill's directory) for the scope, arguments, and how to report.

## Steps

1. Grep the diff for likely hardcoded secrets/config: API keys, tokens,
   passwords, connection strings with embedded credentials, private keys.
   Skip obviously fake test fixtures (e.g. `"test-api-key-123"`) unless
   they're indistinguishable from something that could be real.
2. Find the project's example/template env file if one exists
   (`.env.example`, `.env.sample`, `config.example.*`, or similar) and the
   code that actually reads config (`os.environ`, `process.env`, a config
   class/module).
3. Diff the two directions:
   - a var read in changed code but missing from the example file (an
     undocumented new requirement)
   - a var in the example file no longer referenced anywhere (stale —
     lower priority, but worth a mention)
4. Flag values that should be config but were hardcoded in the diff
   instead (URLs, credentials, feature flags, environment-specific
   constants baked directly into source).

## Output

A list of findings, each with: file:line, what's wrong (hardcoded secret /
undocumented env var / stale example entry), and a concrete fix. Never
repeat a secret's value in a finding. Show at most its first four
characters (e.g. `sk-a…`), because findings are copied into task lists
and issues. See
`../_shared/finding-format.md` for the standalone-vs-delegated
reporting convention.

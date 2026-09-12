---
name: dependency-audit-check
description: Check dependencies changed in the diff for known vulnerabilities, license conflicts, unused additions, and abandoned packages. Use standalone or as part of pr-check.
---

# Dependency Audit Check

Focus on dependencies the diff actually touches — new packages and version
bumps — not a full inventory of everything already in the lockfile.

## Steps

1. Identify the project's package manager(s) from the manifests/lockfiles
   present (`package.json`/`package-lock.json`/`yarn.lock`/`pnpm-lock.yaml`,
   `pyproject.toml`/`poetry.lock`/`uv.lock`/`requirements.txt`, `Cargo.toml`/
   `Cargo.lock`, `go.mod`/`go.sum`, etc.).
2. Run the ecosystem's audit tool if it's available in this environment
   (`npm audit`, `pip-audit`, `cargo audit`, `govulncheck`, etc.). If no
   audit tool is installed, say so rather than trying to install new
   tooling — don't add dependencies to solve a dependency-check task.
3. Cross-reference the diff specifically: which packages were added or had
   their version bumped. Prioritize findings on those over pre-existing
   transitive deps outside the diff's control.
4. Flag:
   - known-vulnerable versions (from the audit tool, or a version pinned
     below a documented patched release)
   - license conflicts — a newly added dependency's license incompatible
     with the project's own declared license (e.g. a copyleft license
     pulled into a permissively-licensed project)
   - added-but-unused — a new dependency with no corresponding import/
     require anywhere in the code (grep before flagging)
   - apparently abandoned packages (no releases in a long time) — flag
     as lower-confidence and say so; don't fabricate a specific last-release
     date if you can't verify one
5. Don't flag a transitive dependency the diff didn't introduce unless a
   direct, in-diff fix exists (e.g. bumping a direct dependency pulls in a
   patched transitive version).

## Output

A list of findings, each with: package name, version, issue type
(vulnerability/license/unused/stale), and a suggested action (bump to
version X, remove, replace, or "no fix available yet — track it"). See
`skills/_shared/finding-format.md` for the standalone-vs-delegated
reporting convention.

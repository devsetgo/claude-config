# claude-config
Claude code skills and other refinements for projects.

Pulled into other projects via VS Code's dotfiles feature — keep everything
here generic and reusable across projects. See `CLAUDE.md` for conventions.

## Setup

1. On your host machine (outside any container), add to VS Code user settings
   (`Preferences: Open User Settings (JSON)`):

   ```json
   {
     "dotfiles.repository": "devsetgo/claude-config",
     "dotfiles.targetPath": "~/claude-config",
     "dotfiles.installCommand": "install.sh"
   }
   ```

2. Every devcontainer built after that clones this repo to `~/claude-config`
   and runs `install.sh`, which symlinks `skills/` into wherever Claude
   Code looks for user-level skills — so every skill here just shows up,
   no per-project devcontainer edits.

To set it up manually on a machine without the dotfiles feature: clone this
repo anywhere and run `./install.sh`.

By default that's `~/.claude/skills`, but the actual location isn't always
the same (Windows, WSL, and server setups can differ) — `install.sh`
honors `CLAUDE_CONFIG_DIR` if it's set in your environment, same as
Claude Code's own CLI, so set that first if your setup uses a
non-default config directory.

## Skills

### Gates

Run before opening a PR or cutting a release. Each orchestrates the
focused checks below, reports a `PASS`/`FAIL`/`N/A` line per item, and
writes failures to the shared `TODO_TASKS.md` worklist rather than
fixing anything automatically.

**[dsg-pr-check](skills/dsg-pr-check/SKILL.md)** — pre-PR standards gate
scoped to the current diff. Runs test coverage, security,
correctness/simplification, documentation freshness, comment coverage,
schema/migration coverage, ignore-file hygiene, dependency audit, error
handling, secrets/config drift, changelog freshness, and API contract
checks in one pass, delegating each to its own focused skill where one
exists.

**[dsg-release-check](skills/dsg-release-check/SKILL.md)** — pre-release
gate for the moment of cutting an actual release, distinct from
`dsg-pr-check`'s per-diff scope: it looks at everything accumulated
since the last release tag instead. Checks version-bump consistency,
changelog freshness, API contract breakage (cross-checked against the
version bump), a full — not diff-only — dependency audit, and, if
Release Drafter is configured, that its accumulated draft notes are
complete and correctly categorized.

### Focused checks

Each finds one specific class of issue and reports it — never fixes
automatically. Usable standalone or delegated from `dsg-pr-check`/
`dsg-release-check`; see `skills/_shared/finding-format.md` for the
shared reporting convention they all follow.

**[dsg-api-check](skills/dsg-api-check/SKILL.md)** — classifies changes
to a public API/schema/library contract as breaking or non-breaking:
required-vs-optional fields, type narrowing, removed/renamed symbols,
changed defaults or validation. Flags genuinely ambiguous cases
explicitly instead of silently picking a side, and suggests a mitigation
(versioning, a backward-compatible default, a deprecation window) for
confirmed breaking changes.

**[dsg-changelog-check](skills/dsg-changelog-check/SKILL.md)** — keeps
`CHANGELOG.md` current for user-facing changes, but first checks whether
Release Drafter (or an equivalent action) already generates release
notes from PR metadata and reports `N/A` rather than hand-editing a file
that automation owns. When invoked standalone rather than delegated, it
writes the missing entries itself under the file's existing "Unreleased"
section, matching its format.

**[dsg-comment-check](skills/dsg-comment-check/SKILL.md)** — spot-checks
new or changed functions for a missing *why* comment — a workaround, a
subtle invariant, a hidden constraint — on genuinely tricky logic.
Doesn't demand comments on self-explanatory code, and doesn't credit a
comment that only restates *what* the code already makes obvious.

**[dsg-coverage-check](skills/dsg-coverage-check/SKILL.md)** — finds
test coverage gaps in the *changed* code specifically, not overall
percentage. Rules out dead code (recommending deletion instead of a
test) and branches unreachable in the current environment before
flagging anything, then prioritizes what's left by risk — auth, data
writes, security-adjacent logic — over raw line count.

**[dsg-dep-check](skills/dsg-dep-check/SKILL.md)** — audits dependencies
the diff actually added or bumped for known vulnerabilities, license
conflicts with the project's own license, dependencies added but never
imported, and apparently abandoned packages. Runs the ecosystem's own
audit tool (`npm audit`, `pip-audit`, `cargo audit`, etc.) when one's
available rather than re-deriving vulnerability data itself.

**[dsg-doc-check](skills/dsg-doc-check/SKILL.md)** — checks whether new
settings, endpoints, tables, or non-obvious behavior changes in the diff
are reflected anywhere in the project's own standards docs (`CLAUDE.md`,
`CONTRIBUTING.md`, a `docs/` folder). Ignores purely internal refactors
with no externally-visible effect.

**[dsg-error-check](skills/dsg-error-check/SKILL.md)** — flags swallowed
exceptions (empty catches, bare `except: pass`), overly broad catches
that absorb unrelated bugs, inconsistent logging between similar error
paths, and error responses that leak internals (stack traces, SQL, file
paths) to external callers. Leaves deliberate, documented pass-through
alone.

**[dsg-secrets-check](skills/dsg-secrets-check/SKILL.md)** — scans the
diff for hardcoded secrets/config values and checks for drift between an
`.env.example`-style template and the env vars actually read by code, in
either direction (an undocumented new var, or a stale entry nothing
references anymore). A lighter, config-focused complement to full secret
scanning, not a replacement for it.

**[dsg-version-check](skills/dsg-version-check/SKILL.md)** — checks that
a version bump was applied consistently everywhere a project declares
its version: manifests, source constants, Docker/Helm labels, API specs.
Recognizes a BumpCalver (`[tool.bumpcalver]`) config as the authoritative
list of tracked files for CalVer projects, instead of guessing manifest
locations generically.

### Backlog cleanup

Finds open issues in an external system, tells real problems apart from
false positives or flaky noise, and fixes what's real in reviewable
batches — keeping `TODO_TASKS.md` current on what's fixed versus
remaining.

**[dsg-actions](skills/dsg-actions/SKILL.md)** — pulls failing GitHub
Actions runs for a branch/PR via the `gh` CLI (REST API fallback if `gh`
isn't installed), isolates the actual error from the log using GitHub's
own `##[error]` annotations instead of dumping the whole run, and
classifies each failure as flaky/infra (recommend a re-run) or real
(test/lint/build) before fixing the real ones — reproducing locally with
the workflow's own command first, no more copy-pasting logs into chat.

**[dsg-sonar](skills/dsg-sonar/SKILL.md)** — pulls open SonarQube/
SonarCloud issues and hotspots for a branch or the whole project via the
API, classifies genuine false positives with a recorded justification
(only after user confirmation, since dismissing one is visible on the
team's shared dashboard), and fixes real issues — bugs, vulnerabilities,
code smells — in batches of roughly 10-15, testing after each.

### Issue tracking

**[dsg-issue-todo](skills/dsg-issue-todo/SKILL.md)** — converts unchecked
`TODO_TASKS.md` entries into GitHub Issues via the `gh` CLI, grouped by
category and severity (critical/high items get their own issue, medium/low
items in the same category batch into one checklist issue). Always shows
the proposed title, body, grouping, and labels and waits for confirmation
before creating anything, since opening issues is visible to the whole
team; matching labels are only ever attached if they already exist in the
repo.

**[dsg-issue-new](skills/dsg-issue-new/SKILL.md)** — turns a plan already
worked out in conversation (a new feature, enhancement, or bug fix) into a
single titled, labeled GitHub Issue with a detailed description drawn from
that plan — same label-matching and mandatory-confirmation rules as
`dsg-issue-todo`, but drafted directly from the conversation instead of a
`TODO_TASKS.md` entry.

### Commit & release authoring

**[dsg-commit](skills/dsg-commit/SKILL.md)** — drafts a commit message
or PR title that correctly signals breaking vs feature vs fix, matching
whatever this repo's release automation actually reads (Release
Drafter's autolabeler patterns, or Conventional Commits), then creates
the commit itself. Asks once per repo (remembered via `git config`)
whether to include an AI co-author attribution trailer, and always asks
for confirmation before pushing, no matter how many times it's already
been confirmed earlier in the same session.

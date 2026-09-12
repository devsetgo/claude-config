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
   and runs `install.sh`, which symlinks `skills/` into `~/.claude/skills` —
   so every skill here just shows up, no per-project devcontainer edits.

To set it up manually on a machine without the dotfiles feature: clone this
repo anywhere and run `./install.sh`.

## Skills

| Skill | Description |
| --- | --- |
| [pr-check](skills/pr-check/SKILL.md) | Pre-PR standards gate over the current diff; runs the checks below plus security/migration/ignore-file checks, then writes failures to a `PR_CHECK_TASKS.md` worklist. |
| [test-coverage-check](skills/test-coverage-check/SKILL.md) | Find test coverage gaps in changed code, ruling out dead code and unreachable branches, prioritized by risk. |
| [doc-freshness-check](skills/doc-freshness-check/SKILL.md) | Check that new settings/endpoints/tables/behavior in a diff are reflected in the project's own docs. |
| [comment-coverage-check](skills/comment-coverage-check/SKILL.md) | Flag changed functions with non-obvious logic and no "why" comment. |
| [dependency-audit-check](skills/dependency-audit-check/SKILL.md) | Check diff-touched dependencies for known vulnerabilities, license conflicts, unused additions, and abandoned packages. |
| [error-handling-check](skills/error-handling-check/SKILL.md) | Flag swallowed exceptions, inconsistent logging, and error responses that leak internals. |
| [secrets-drift-check](skills/secrets-drift-check/SKILL.md) | Flag hardcoded secrets/config and drift between `.env.example` and env vars actually read by code. |
| [changelog-check](skills/changelog-check/SKILL.md) | Keep `CHANGELOG.md` current for user-facing changes; N/A on repos where Release Drafter (or similar) already generates it. |
| [commit-message](skills/commit-message/SKILL.md) | Draft a commit message/PR title that signals breaking vs feature vs fix, matching this repo's release automation. |
| [api-contract-check](skills/api-contract-check/SKILL.md) | Classify API/schema changes as breaking or non-breaking (required vs optional, type changes, removals). |
| [release-check](skills/release-check/SKILL.md) | Pre-release gate over everything since the last tag: version-bump consistency, changelog, API contract, full dependency audit, release-notes sanity. |
| [version-bump-check](skills/version-bump-check/SKILL.md) | Check a version bump was applied consistently across every manifest/constant/label that declares it. |

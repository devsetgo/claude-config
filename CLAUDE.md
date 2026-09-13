# claude-config

Reusable Claude Code skills, agents, and other configuration that gets pulled
into other projects via VS Code's dotfiles feature. Nothing in here should be
specific to any one project — if a skill needs project-specific content, that
belongs in the target project's own `CLAUDE.md`, not here.

## Conventions

- One directory per skill under `skills/<skill-name>/`, with a `SKILL.md`
  containing YAML frontmatter (`name`, `description`) followed by the
  instructions body. Follow the existing skills for tone and structure.
- Keep skills generic and reusable. Don't bake in assumptions about a
  specific stack, team, or repo — those change per project; this repo is
  shared across all of them.
- Prefer delegating to other Claude Code skills/commands where they already
  exist (e.g. `security-review`, `code-review`) rather than reimplementing
  that logic here.
- Update the skills index in `README.md` whenever a skill is added, renamed,
  or removed.
- A `*-check` skill (a review skill that surfaces findings rather than
  performing an action) should follow `skills/_shared/finding-format.md`
  for its Output section instead of restating the standalone-vs-delegated
  convention inline — link to it. If that convention changes, it should
  only need editing in one place.
- An orchestrator skill (e.g. `pr-check`, `release-check`) delegates to
  focused single-purpose skills rather than inlining their logic; only
  keep a check inline when it's genuinely too small/project-specific to
  reuse elsewhere (e.g. ignore-file hygiene).
- Any skill that turns findings into a worklist — an orchestrator's FAIL
  items (`pr-check`, `release-check`), or a backlog-working skill's open
  items (`sonar-cleanup`) — writes to the single shared `TODO_TASKS.md`
  (in the target repo, not this one). Follow
  `skills/_shared/task-list.md`'s file/structure/cleanup convention rather
  than spawning a per-skill task file. Any new skill with a worklist added
  later should use the same file, not a new one.

## Layout

- `skills/` — one subdirectory per skill (`SKILL.md` + any supporting files).
- `skills/_shared/` — reference docs linked from multiple skills' bodies;
  not a skill itself (no `SKILL.md`, not independently invokable).
- `agents/` — reusable subagent definitions, if/when added.
- `install.sh` — symlinks `skills/` to `~/.claude/skills`; this is what
  actually makes the "pulled in via VS Code's dotfiles feature" claim in
  `README.md` true. Never make it copy files instead of symlinking — the
  whole point is that a `git pull` here updates every devcontainer with
  no reinstall step.

## Repo automation

- `.github/workflows/skill-lint.yml` — validates every `skills/*/SKILL.md`
  has `name`/`description` frontmatter matching its directory, and that
  `README.md`'s skill table stays in sync with what's under `skills/`.
- `.github/workflows/release-drafter.yml` +
  `.github/release-drafter.yml` — drafts a categorized changelog from
  merged PRs, visible in the GitHub Releases tab. This repo doesn't tag
  versioned releases (see the comment at the top of the config) — it's
  informational only, so don't publish the draft as a numbered release.
  PR titles in Conventional Commits style (`feat:`, `fix:`, `chore:`,
  etc.) get autolabeled correctly regardless of branch name; see the
  `commit-message` skill for drafting those.
- Workflow: changes go on `dev`, opened as a PR into `main` (see
  `pr-check`/`release-check` for the review gates to run against that
  PR before merging).

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

## Layout

- `skills/` — one subdirectory per skill (`SKILL.md` + any supporting files).
- `skills/_shared/` — reference docs linked from multiple skills' bodies;
  not a skill itself (no `SKILL.md`, not independently invokable).
- `agents/` — reusable subagent definitions, if/when added.

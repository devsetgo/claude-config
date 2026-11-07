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
  only need editing in one place. It also sets `context: fork`,
  `model: sonnet` and `background: false` in its frontmatter, plus one
  body line pointing the forked sub-agent at that doc, which defines its
  scope and arguments. A fork sees no conversation, so an orchestrator
  must pass everything a check needs (base, category, docs) as
  arguments, and start independent checks in one turn.
- An orchestrator skill (e.g. `dsg-pr-check`, `dsg-release-check`)
  delegates to focused single-purpose skills rather than inlining their
  logic; only keep a check inline when it's genuinely too
  small/project-specific to reuse elsewhere (e.g. ignore-file hygiene).
- Any skill that turns findings into a worklist — an orchestrator's FAIL
  items (`dsg-pr-check`, `dsg-release-check`), or a backlog-working
  skill's open items (`dsg-sonar`) — writes to the single shared
  `TODO_TASKS.md` (in the target repo, not this one). Follow
  `skills/_shared/task-list.md`'s file/structure/cleanup convention rather
  than spawning a per-skill task file. Any new skill with a worklist added
  later should use the same file, not a new one.

- `global/rules/` holds only instructions that apply to every project —
  no stack-, team-, or repo-specific rules (those go in the target
  project's own `CLAUDE.md`). Everything there is in context on every
  turn of every session, so keep each file short; use `paths:`
  frontmatter for rules that only matter when certain files are touched.
  Link it rather than a `CLAUDE.md` so each user's own
  `~/.claude/CLAUDE.md` stays theirs.

## Layout

- `skills/` — one subdirectory per skill (`SKILL.md` + any supporting files).
- `skills/_shared/` — reference docs linked from multiple skills' bodies;
  not a skill itself (no `SKILL.md`, not independently invokable).
- `agents/` — reusable subagent definitions, if/when added.
- `global/rules/` — every-project instruction files, symlinked to
  `~/.claude/rules/` by `install.sh`.
- `hooks/` — SessionStart hooks `install.sh` registers in the user's
  `settings.json`: `dsg-update-check.sh` (reports when the clone is
  behind, suggesting `dsg-update`) and `dsg-tasks-context.sh` (loads
  `TODO_TASKS.md`'s `## In progress` section). `settings_hook.py` merges
  one entry per script into `settings.json`, and `settings_env.py` (which
  reuses its load/save) sets the opt-in `CLAUDE_CODE_SUBAGENT_MODEL` from
  `DSG_SUBAGENT_MODEL`. Hooks must never block or
  fail a session: keep network calls in detached background jobs, and
  keep output small, because it lands in every session's context.
- `VERSION` + `bumpcalver.toml` — the current release version and the
  BumpCalver config that bumps it (see Repo automation).
- `install.sh` — symlinks `skills/` to `~/.claude/skills` and
  `global/rules/` to `~/.claude/rules`, and registers the hooks above;
  this is what
  actually makes the "pulled in via VS Code's dotfiles feature" claim in
  `README.md` true. Never make it copy files instead of symlinking — the
  whole point is that a `git pull` here updates every devcontainer with
  no reinstall step. `skills/synced/` is gitignored: Claude Code writes
  account-synced skills to `~/.claude/skills/synced/`, which lands in the
  repo through that symlink. `DSG_SHARED_CLAUDE_DIR=1` (set by a
  devcontainer that mounts the host's config dir, see `dsg-devcontainer`)
  makes `install.sh` a no-op so it can't re-point the host's links.

## Repo automation

- `.github/workflows/skill-lint.yml` — validates every `skills/*/SKILL.md`
  has `name`/`description` frontmatter matching its directory, and that
  `README.md`'s skill table stays in sync with what's under `skills/`.
  Also runs `.github/scripts/test_install.sh`, which exercises
  `install.sh` against throwaway HOMEs (fresh, re-run, repoint, conflict,
  `CLAUDE_CONFIG_DIR`, settings.json hook merge), and
  `test_dsg_update_check.sh`, which runs the dsg-update hook against a
  throwaway origin/clone, and `test_dsg_tasks_context.sh`, which runs the
  tasks-context hook against sample `TODO_TASKS.md` files.
- `.github/workflows/release-drafter.yml` +
  `.github/release-drafter.yml` — drafts a categorized changelog from
  merged PRs, visible in the GitHub Releases tab. Don't publish the draft
  by hand; the Release workflow below does that.
  PR titles in Conventional Commits style (`feat:`, `fix:`, `chore:`,
  etc.) get autolabeled correctly regardless of branch name; see the
  `dsg-commit` skill for drafting those. Since Release Drafter v7 the
  autolabeler is a separate `release-drafter/autolabeler` action, run as
  its own job on `pull_request_target` (including `edited`, so a retitle
  relabels); the drafter job only runs on push to `main`. Keep the
  `title:` autolabeler rules — PRs here come from `dev`, so `branch:`
  rules alone never match.
- `.github/workflows/release.yml` — manual (`workflow_dispatch`, `main`
  only) release: BumpCalver bumps `VERSION` to `YYYY.MM.DD.N` (the build
  number counts releases that UTC day; see `bumpcalver.toml`), commits and
  tags it (bare tag, no `v`), pushes, and publishes Release Drafter's draft
  under that tag. Both release workflows pass Release Drafter an explicit
  `from` baseline (`.github/scripts/release_baseline.sh`: the newest
  CalVer tag, or the first commit before any release), because v7 finds
  no changes at all without a published release. Versioning is CalVer via BumpCalver, never SemVer.
  Releases mark batches; clones still track `main` itself (dotfiles always
  clones the branch), and the `dsg-update` hook announces only a new
  release once `VERSION` exists. Never edit `VERSION` or create release
  tags by hand. Run `dsg-release-check` before cutting one. After a release,
  fast-forward `dev` to `main`, since the bump commit lands on `main`.
- `.github/workflows/autofill-pr.yml` — runs `devsetgo/ai-pr-assistant`
  (OpenAI, `OPENAI_API_KEY` repo secret) to fill in PR descriptions
  ("smart": keeps a good one, extends or replaces a thin one), titles,
  labels, and breaking-change flags. It's tuned not to fight Release
  Drafter's title-based autolabeler: titles are only suggested in the
  action log, never applied (`smart` rewrote a correct `ci:` title into
  unprefixed prose), labels come from Release
  Drafter's category labels and are only added to an unlabeled PR, and
  the action's `breaking-change` label is mapped in
  `release-drafter.yml`. Keep those in sync if either side's labels
  change. No secret set = silent no-op, not a failure.
- Workflow: changes go on `dev`, opened as a PR into `main` (see
  `dsg-pr-check`/`dsg-release-check` for the review gates to run against
  that PR before merging).

---
name: commit-message
description: Draft a commit message and/or PR title that correctly signals breaking changes vs features vs fixes, matching whatever this repo's release automation (Release Drafter autolabeler, semantic-release, Conventional Commits) actually reads — then create the commit. Asks once per repo whether to credit the AI as co-author, and always asks before pushing. Use when preparing a commit or opening a PR.
---

# Commit Message

Structure the message so downstream automation categorizes it correctly
without a human re-labeling the PR by hand afterward — and so a person
skimming history can tell at a glance what kind of change it was. This
skill both drafts the message and creates the commit; it does not push
without asking.

## Steps

1. **AI attribution preference** — check once per repo, then remember it:
   - Read `git config --local --get claude.commitMessage.aiCredit`.
   - If it's unset (first run in this repo), ask the user whether commits
     made by this skill should include an AI attribution trailer (e.g.
     `Co-Authored-By: Claude <model> <noreply@anthropic.com>`, matching
     whatever attribution convention this session is already using).
     Save the answer with
     `git config --local claude.commitMessage.aiCredit true` (or `false`)
     so future invocations in this repo don't ask again.
   - If the user later wants to change their answer, just say so — update
     the stored config value rather than asking every time.

2. Check what this repo's automation actually expects before picking a
   format — don't default to Conventional Commits if the repo uses
   something else:
   - **Release Drafter** — read `.github/release-drafter.yml`'s
     `autolabeler` section (it typically matches PR/commit title patterns
     like `^feat`, `^fix`, or branch-name patterns) and `categories`
     (which labels map to which changelog section). Match those patterns
     exactly; a title matching no rule falls back to "uncategorized" or
     gets dropped from the release notes entirely.
   - **No Release Drafter** — default to Conventional Commits (`feat:`,
     `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, a `!` after the type
     or a `BREAKING CHANGE:` footer for breaking changes), unless recent
     commit history shows this project already follows a different
     convention.

3. Look at the actual diff — don't take a verbal description of the
   change at face value if the code shows something else (e.g. called a
   "fix" but it also removes a parameter — that's breaking, not just a fix).

4. Classify the change:
   - **Breaking** — removes/renames a public symbol, endpoint, or config
     key; narrows an accepted type; changes a default in a way that
     changes existing callers' behavior.
   - **Feature/enhancement** — additive, backward-compatible.
   - **Fix** — corrects incorrect behavior without changing the contract.
   - **Other** — chore/docs/refactor/test/ci, no user-facing effect.

   If the diff touches a public API/schema, this overlaps with
   `api-contract-check` — defer to its breaking/non-breaking call when
   both are in play rather than reclassifying independently.

5. Draft the message matching whichever convention step 2 determined,
   with the breaking-change marker prominent — don't bury a
   `BREAKING CHANGE:` footer under an otherwise plain-looking title.
   Release Drafter and semantic-release key off it programmatically, but
   a human skimming PR titles should also be able to spot it immediately.
   Append the AI attribution trailer from step 1 to the commit message
   body if that preference is `true` — it's a trailer on the commit
   message, not something that belongs in a PR title.

6. If `changelog-check` determined this repo hand-maintains
   `CHANGELOG.md` (no Release Drafter present), also draft an entry there
   in the same pass. Skip this when Release Drafter is present — it
   generates the changelog from this same PR/commit metadata, so a
   hand-written entry would duplicate or drift from it.

7. **Create the commit.** Review `git status`/`git diff` and stage the
   files the change actually touches (specific paths, not a blind
   `git add -A`) — double-check anything that looks like it could hold a
   secret before staging it. Create the commit with the drafted message.

8. **Ask before pushing.** Never push automatically, including on a
   second or later invocation in the same session — creating the commit
   is this skill's job, pushing is a separate, explicit yes each time.
   If the user confirms, push; otherwise stop after the commit.

## Output

Show the drafted commit message (and PR title, if this repo's automation
reads a separate one) plus a one-line note on why it was classified that
way. If a `CHANGELOG.md` entry was also drafted, show it. Confirm the
commit was created (with its hash). Don't push or open a PR yourself
until the user says so.

---
name: commit-message
description: Draft a commit message and/or PR title that correctly signals breaking changes vs features vs fixes, matching whatever this repo's release automation (Release Drafter autolabeler, semantic-release, Conventional Commits) actually reads. Use when preparing a commit or opening a PR.
---

# Commit Message

Structure the message so downstream automation categorizes it correctly
without a human re-labeling the PR by hand afterward — and so a person
skimming history can tell at a glance what kind of change it was.

## Steps

1. Check what this repo's automation actually expects before picking a
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

2. Look at the actual diff — don't take a verbal description of the
   change at face value if the code shows something else (e.g. called a
   "fix" but it also removes a parameter — that's breaking, not just a fix).

3. Classify the change:
   - **Breaking** — removes/renames a public symbol, endpoint, or config
     key; narrows an accepted type; changes a default in a way that
     changes existing callers' behavior.
   - **Feature/enhancement** — additive, backward-compatible.
   - **Fix** — corrects incorrect behavior without changing the contract.
   - **Other** — chore/docs/refactor/test/ci, no user-facing effect.

   If the diff touches a public API/schema, this overlaps with
   `api-contract-check` — defer to its breaking/non-breaking call when
   both are in play rather than reclassifying independently.

4. Draft the message matching whichever convention step 1 determined,
   with the breaking-change marker prominent — don't bury a
   `BREAKING CHANGE:` footer under an otherwise plain-looking title.
   Release Drafter and semantic-release key off it programmatically, but
   a human skimming PR titles should also be able to spot it immediately.

5. If `changelog-check` determined this repo hand-maintains
   `CHANGELOG.md` (no Release Drafter present), also draft an entry there
   in the same pass. Skip this when Release Drafter is present — it
   generates the changelog from this same PR/commit metadata, so a
   hand-written entry would duplicate or drift from it.

## Output

The drafted commit message (or PR title, whichever this repo's automation
actually reads) plus a one-line note on why it was classified that way.
If a `CHANGELOG.md` entry was also drafted, show it. Don't create the
commit, push, or open the PR yourself unless separately asked — this
drafts the message, it doesn't perform the git/GitHub action.

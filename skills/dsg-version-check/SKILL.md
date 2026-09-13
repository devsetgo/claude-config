---
name: dsg-version-check
description: Check that a version bump is applied consistently across every place this project declares its version — manifests, source constants, Docker/Helm labels, API specs. Recognizes BumpCalver (CalVer) config as the source of truth when present. Use when cutting a release, or standalone whenever a diff touches a version string.
---

# Version Bump Check

Version drift usually happens because a project declares its version in
more than one place and only some of them get updated. Find every
declaration site and confirm they agree.

## Step 0: check for BumpCalver first

Look for a `[tool.bumpcalver]` section in `pyproject.toml`, or a standalone
`bumpcalver.toml`. If present, this project uses
[BumpCalver](https://github.com/devsetgo/bumpcalver) for calendar
versioning (CalVer) — treat its config as the authoritative list of
version-declaration sites instead of guessing manifest locations:

- Each `[[tool.bumpcalver.file]]` entry names one tracked file (`path`,
  `file_type`, and either `variable` or `pattern`). Read the whole list —
  that list *is* the set of places that must agree, nothing more, nothing
  less.
- Sanity-check the config itself, not just the files: confirm each
  entry's `path` still exists, `file_type` still matches that file's
  actual format, and the `variable`/`pattern` still actually locates a
  version string in it. A `variable` name left stale after a refactor is
  the most common way this silently stops working.
- Confirm every tracked file currently holds the same version value.
- Grep for version-looking strings in files *not* in the tracked list
  (other manifests, Docker labels, API specs). Anything found there is a
  location BumpCalver can't keep in sync — flag it as either a candidate
  to add to `[[tool.bumpcalver.file]]`, or a leftover to remove if it's no
  longer meant to track the project version.
- This project is on CalVer, not SemVer: the version is date + build
  count (per `version_format`/`date_format`), not a major.minor.patch
  bump. Don't apply semver-shaped expectations (e.g. "a breaking change
  needs a major-version bump") to it elsewhere in a review — see
  `dsg-release-check`'s note on this.

If no BumpCalver config is found, fall back to the generic sweep below.

## Steps (no BumpCalver / generic projects)

1. Find every place this project declares its own version:
   - package manifests (`package.json`, `pyproject.toml`, `Cargo.toml`,
     `*.csproj`, `gemspec`, etc.)
   - a source-level constant (`__version__`, `VERSION`, `version.go`, etc.)
   - Docker image tags/labels (`LABEL version=`, a tag in a `docker-compose`
     or CI deploy config)
   - Helm chart (`Chart.yaml`'s `version`/`appVersion`)
   - an API spec's own version field (OpenAPI `info.version`, GraphQL
     schema version comment) — only if this project treats that as tied
     to the package version rather than versioned independently
2. Determine the target version: whichever one already changed in the
   diff, or (if invoked standalone at release time) the version being
   released.
3. Confirm every other declaration site matches the target. Flag any that
   weren't bumped, or that were bumped to a different value.
4. Don't flag a location that intentionally uses an independent versioning
   scheme (e.g. an API version that only bumps on breaking changes, not on
   every release) — but note the distinction so it's clear the mismatch
   was intentional, not overlooked.

## Output

A list of mismatched or missed locations, each with: file:line, current
value, expected value. See `skills/_shared/finding-format.md` for the
standalone-vs-delegated reporting convention.

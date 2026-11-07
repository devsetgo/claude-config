#!/usr/bin/env bash
# Prints the ref Release Drafter should compare against: the newest CalVer
# release tag (YYYY.MM.DD.N, version-sorted so .10 follows .9), or the
# repo's first commit before any release exists. Release Drafter v7 finds
# no changes at all without a published release, so both the running
# draft and the first release need this passed as `from`.
set -euo pipefail
base="$(git tag --list '[0-9]*.[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)"
[ -n "$base" ] || base="$(git rev-list --max-parents=0 HEAD | tail -1)"
echo "$base"

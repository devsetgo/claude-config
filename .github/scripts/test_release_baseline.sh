#!/usr/bin/env bash
# Checks release_baseline.sh picks the right comparison base for Release
# Drafter in a throwaway repo.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
SCRIPT="$REPO_DIR/.github/scripts/release_baseline.sh"
cd "$WORK" && git init -q -b main
git commit -q --allow-empty -m root
root="$(git rev-parse HEAD)"

echo "== no release tags: the first commit"
git commit -q --allow-empty -m two
git tag v1.0.0  # not a CalVer release tag; ignored
[ "$("$SCRIPT")" = "$root" ] || fail "expected the root commit"

echo "== newest CalVer tag, version-sorted"
git tag 2026.11.07.9
git commit -q --allow-empty -m three
git tag 2026.11.07.10
git tag 2026.11.06.12
[ "$("$SCRIPT")" = 2026.11.07.10 ] || fail "expected 2026.11.07.10, got $("$SCRIPT")"

echo "release baseline tests OK"

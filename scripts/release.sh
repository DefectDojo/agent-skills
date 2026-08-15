#!/usr/bin/env bash
# Tag a release.
#
# Fails closed on any disagreement between VERSION and the plugin manifests,
# because a half-bumped release means some plugins update for users and others
# silently do not.
#
# Claude Code resolves a plugin's version from tags named
# {plugin-name}--v{version} on the marketplace repository, so every plugin gets
# its own tag at the same version.
#
# Usage: scripts/release.sh [--push]

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

push=0
[ "${1:-}" = "--push" ] && push=1

version="$(cat VERSION)"
printf 'Releasing %s\n\n' "$version"

# 1. Manifests must agree with VERSION.
fail=0
for f in plugins/*/.claude-plugin/plugin.json; do
  got="$(jq -r '.version // empty' "$f")"
  if [ "$got" != "$version" ]; then
    printf 'version mismatch in %s: %s\n' "$f" "${got:-none}" >&2
    fail=1
  fi
done
[ "$fail" -eq 0 ] || { printf '\nRun scripts/bump-version.sh %s first.\n' "$version" >&2; exit 1; }

# 2. The tree must be clean, so the tag means what it says.
if [ -n "$(git status --porcelain)" ]; then
  printf 'working tree is dirty; commit before releasing\n' >&2
  exit 1
fi

# 3. Tests and validation must pass.
./tests/test_dd_api.sh > /dev/null || { printf 'tests failed\n' >&2; exit 1; }
printf 'tests pass\n'

if command -v claude > /dev/null 2>&1; then
  claude plugin validate . --strict || { printf 'validation failed\n' >&2; exit 1; }
  printf 'validation passes\n'
else
  printf 'claude CLI not found, skipping plugin validation\n' >&2
fi

# 4. Tag every plugin.
printf '\n'
for f in plugins/*/.claude-plugin/plugin.json; do
  name="$(jq -r '.name' "$f")"
  tag="${name}--v${version}"
  if git rev-parse "$tag" > /dev/null 2>&1; then
    printf 'tag already exists: %s\n' "$tag"
  else
    git tag -a "$tag" -m "$name $version"
    printf 'tagged %s\n' "$tag"
  fi
done

if [ "$push" -eq 1 ]; then
  git push --tags
  printf '\ntags pushed\n'
else
  printf '\nDry run. Re-run with --push to publish the tags.\n'
fi

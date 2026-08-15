#!/usr/bin/env bash
# Set every plugin to one version, from a single source of truth.
#
# All plugins in this repository release together at the same version. Users
# receive updates only when the version string changes, so a content change
# without a bump never reaches anyone who already installed the plugin.
#
# Usage: scripts/bump-version.sh 1.1.0

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

new="${1:-}"
if ! printf '%s' "$new" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  printf 'usage: scripts/bump-version.sh <major.minor.patch>\n' >&2
  exit 2
fi

old="$(cat VERSION)"
printf '%s\n' "$new" > VERSION

for f in plugins/*/.claude-plugin/plugin.json; do
  tmp="$(mktemp)"
  jq --arg v "$new" '.version = $v' "$f" > "$tmp"
  mv "$tmp" "$f"
  printf 'updated %s\n' "$f"
done

printf '\n%s -> %s\n' "$old" "$new"
printf 'Next: add a CHANGELOG entry, commit, then scripts/release.sh\n'

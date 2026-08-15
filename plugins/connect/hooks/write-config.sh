#!/usr/bin/env bash
# Bridges plugin settings into a file that dd-api can read.
#
# Why this exists: the plugin asks for the instance URL and API token once, at
# enable time, and Claude Code keeps the token in the OS keychain. Those values
# reach hook processes as CLAUDE_PLUGIN_OPTION_* environment variables, but
# they are NOT exported to ordinary Bash tool calls. This hook is therefore the
# only sanctioned bridge between the stored settings and the dd-api command.
#
# Do not "simplify" dd-api to read CLAUDE_PLUGIN_OPTION_* directly. Those
# variables are not present outside hook processes and it would fail silently
# in normal use.
#
# The file is written with owner-only permissions, in the same spirit as
# ~/.netrc or ~/.aws/credentials, and only rewritten when the contents change
# so its mtime stays meaningful.

set -uo pipefail

CONFIG_DIR="${DD_CONFIG_DIR:-$HOME/.defectdojo}"
CONFIG_FILE="${DD_CONFIG_FILE:-$CONFIG_DIR/claude-code.json}"

url="${CLAUDE_PLUGIN_OPTION_DD_URL:-}"
token="${CLAUDE_PLUGIN_OPTION_DD_API_TOKEN:-}"

# Nothing configured yet. Stay silent: the connection doctor and dd-api both
# explain the situation far better than a hook can, and a noisy hook on every
# session start would be worse than useless.
if [ -z "$url" ] || [ -z "$token" ]; then
  exit 0
fi

url="${url%/}"

umask 077
mkdir -p "$CONFIG_DIR" 2>/dev/null || exit 0

escape_json() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

new_contents="$(printf '{\n  "url": "%s",\n  "token": "%s"\n}\n' \
  "$(escape_json "$url")" "$(escape_json "$token")")"

if [ -r "$CONFIG_FILE" ] && [ "$(cat "$CONFIG_FILE")" = "$new_contents" ]; then
  exit 0
fi

printf '%s' "$new_contents" > "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE" 2>/dev/null || true

exit 0

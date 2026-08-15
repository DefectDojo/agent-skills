# defectdojo-connect

Connects Claude Code to your DefectDojo Pro instance. Every other DefectDojo
plugin depends on this one, so you rarely install it deliberately.

## What it provides

- The MCP server connection to `https://your-instance/mcp`, which is where the
  `mcp__defectdojo__*` read tools come from.
- One-time credential entry. Your instance URL and API v2 key are requested when
  the plugin is enabled; the key goes to your operating system keychain.
- `dd-api`, the REST bridge every skill uses for anything the read tools do not
  cover: status changes, notes, imports, and reporting.
- `dd-link`, which prints deep links into the DefectDojo UI.
- The `connection-doctor` skill.

## dd-api

Available as a command while the plugin is enabled.

```
dd-api config                    # instance and credential source, never the token
dd-api whoami                    # verify credentials
dd-api get "/api/v2/findings/?active=true&o=-priority&limit=10"
dd-api close-finding 4711 --note "Fixed in 1.4.2"
dd-api import --file scan.json --scan-type "Semgrep JSON Report" --auto_create_context true
```

Exit codes are contractual: 2 usage, 3 not configured, 4 authentication or
permission, 5 not a Pro instance, 6 HTTP error, 7 import timeout.

## The Pro requirement

`dd-api` verifies on first contact that the instance is DefectDojo Pro, by
probing a Pro-only endpoint, and refuses to run otherwise. The result is cached
per instance. The MCP server applies its own equivalent check.

There is no way to disable this and no reduced open source mode.

## Credentials

Written to `~/.defectdojo/claude-code.json` with owner-only permissions at
session start, from your plugin settings. Do not edit that file by hand; it is
rewritten each session. To change credentials, run `/plugin`, configure this
plugin, and start a new session.

For CI, set `DD_BASE_URL` and `DD_API_TOKEN` instead. They take priority.

See [SECURITY.md](../../SECURITY.md) for the full credential model.

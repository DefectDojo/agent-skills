# DefectDojo agent skills

Official DefectDojo skills for Claude Code. Query, triage, import, and report on
your vulnerability data from the terminal you already work in.

Your DefectDojo Pro instance already speaks MCP. These plugins teach your coding
agent what to do with it.

## Install

```
/plugin marketplace add DefectDojo/agent-skills
/plugin install defectdojo@defectdojo
```

On enable you are asked for two things: your DefectDojo Pro instance URL and
your API v2 key. The key is stored in your operating system keychain. Start a
new session afterwards so the MCP server connects.

Then ask something like:

> What are the top 10 findings we should fix first?

## Requires DefectDojo Pro

These plugins require **DefectDojo Pro** and refuse to run against DefectDojo
open source. The capabilities they are built on, the in-product MCP server and
the Pro API surface, exist only in Pro. There is no reduced open source mode.

To evaluate Pro, start a two-week SaaS trial at [defectdojo.com](https://defectdojo.com).

## What is in the box

Installing `defectdojo` pulls the full set. You can also install any single
plugin; each one pulls in `defectdojo-connect` automatically.

| Plugin | What it does |
|---|---|
| `defectdojo-connect` | Connection, credentials, the `dd-api` bridge, and a connection doctor |
| `defectdojo-triage` | Ask about findings in plain language, then work the triage queue |
| `defectdojo-import` | Import scans and SBOMs, and wire scan upload into CI |
| `defectdojo-report` | Executive, program, and remediation reporting |

### Skills

| Skill | Ask it for |
|---|---|
| `connection-doctor` | "Is DefectDojo connected?", or any 401, 403, or missing-tool problem |
| `findings-query` | "How many criticals are open?", "What should we fix first?", "Give me a brief" |
| `triage-findings` | "Mark these false positive", "Close 4711", "Risk accept these" |
| `import-scans` | "Get this Semgrep output into Dojo", "Import this SBOM" |
| `wire-ci-import` | "Push our scans to DefectDojo from CI" |
| `security-report` | "Build the quarterly report for the board" |

## How it connects

Credentials are entered once and drive two channels.

**MCP.** The plugin points Claude Code at the MCP server built into your
instance, at `https://your-instance/mcp`. That provides the read tools, named
`mcp__defectdojo__*`.

**REST.** A command called `dd-api` is available to skills while the plugin is
enabled, and handles everything the read tools do not cover: status changes,
notes, imports, and reporting. It is the single place where the auth header,
error handling, background-import polling, and the Pro edition check live.

Your token is never shown to the model. Every action runs as you, under your
existing DefectDojo permissions.

### Using it in CI

Set two environment variables instead of configuring the plugin:

```
DD_BASE_URL=https://your-instance.example.com
DD_API_TOKEN=<a service account API key>
```

Use a dedicated service account, not a personal token. Personal tokens expire
and carry one person's permissions.

## Requirements

- DefectDojo Pro, with the MCP server enabled by an administrator
- Claude Code 2.1.143 or newer, so umbrella dependencies enable transitively
- macOS or Linux, including WSL. Native Windows is not supported yet

## Development

```
claude --plugin-dir ./plugins/connect --plugin-dir ./plugins/triage
./tests/test_dd_api.sh
claude plugin validate . --strict
```

`tests/test_dd_api.sh` runs `dd-api` against a stub DefectDojo covering the Pro
path, an open source instance, expired credentials, and synchronous, background,
and failing imports. It needs only bash, curl, and python3.

## Support

Open an issue at
[github.com/DefectDojo/agent-skills](https://github.com/DefectDojo/agent-skills/issues).
For a security issue, see [SECURITY.md](SECURITY.md).

Documentation: [docs.defectdojo.com](https://docs.defectdojo.com)

## License

Source-available, not open source. See [LICENSE](LICENSE).

The source is published so that customers can read what runs against their
vulnerability data before they run it. You may install it, use it against a
DefectDojo Pro instance you are authorized to use, and review the source.
Modifying it, redistributing it, or adapting it to run against anything other
than DefectDojo Pro is not permitted.

DefectDojo Community Edition is separate and remains open source under its own
license. This license covers only this repository.

For permissions beyond the license, contact legal@defectdojo.com.

# Connection troubleshooting

Read this when the ordered probes in the skill did not resolve the failure.

## The two MCP toggles

The MCP server is gated twice, and they fail differently.

**Deploy time.** `MCP_ENABLED` controls whether the instance serves `/mcp` at
all. On a self-hosted deployment this is an environment setting; the web server
routes `/mcp` only when it is on. Symptom: `/mcp` returns a 404 from the web
server rather than anything DefectDojo shaped.

**Runtime.** A toggle in the Pro UI under the AI settings controls whether the
MCP server accepts work. It is live and needs no restart. Any authenticated user
can see it; only a superuser can change it. Symptom: the endpoint exists and
answers, but rejects with an authentication-style failure naming MCP.

REST working while MCP tools are missing points at one of these two, not at the
credentials.

## Symptom to cause

| Symptom | Likely cause |
|---|---|
| REST fine, no `mcp__defectdojo__*` tools in the session | MCP disabled on the instance, or the session started before configuration |
| `dd-api` exits 5 on a genuinely Pro instance | URL includes a path, or a gateway is returning its own 404 |
| Everything worked, now 401 mid-session | Token expired. Issue a new one, reconfigure, start a new session |
| One operation 403s, everything else fine | RBAC on that object. Not a connection problem |
| Works in browser, fails here | SSO or proxy in front of the API, or a private certificate authority |
| Intermittent failures | Load balancer with an idle timeout, or streaming buffered by a proxy |

## URL shape

The configured URL is the application root, with no trailing slash and no path.

```
https://yourcompany.cloud.defectdojo.com          correct
https://yourcompany.cloud.defectdojo.com/         tolerated, trailing slash trimmed
https://yourcompany.cloud.defectdojo.com/api/v2   wrong
https://yourcompany.cloud.defectdojo.com/mcp      wrong, the plugin appends /mcp itself
```

## Proxies, SSO and certificates

A gateway in front of DefectDojo can return its own 404 for `/api/mcp/`, which
looks exactly like an open source instance. If the user can reach the API from a
browser but the probe 404s, ask what sits in front of the application.

An SSO portal that intercepts API paths will return HTML rather than JSON. The
tell is an HTTP error whose body starts with a document rather than a brace.

For a private certificate authority, the correct fix is installing the CA
certificate in the operating system trust store. Do not suggest disabling
certificate verification.

## Self-hosted specifics

The MCP server runs as its own service alongside the application, and the web
server proxies `/mcp` to it. Common failures: the service is not running, the
proxy configuration was not included because `MCP_ENABLED` was off at start,
or response buffering breaks streaming. The MCP transport is streamable HTTP.
Server-sent events are not supported and stdio is not offered, so a client
configured for either will not connect.

## Version floors

The MCP server needs a recent DefectDojo Pro. If the instance predates it,
`/api/mcp/` may be absent and the probe reports the instance as not Pro. Check
`dd-api version` and compare against the documented minimum before concluding
the deployment is broken.

Claude Code itself needs 2.1.143 or newer for a plugin's dependencies to be
enabled transitively. On older versions the umbrella installs the other plugins
but does not enable them, so skills appear missing. `claude --version` tells you.

## Credentials

`~/.defectdojo/claude-code.json` is written at session start from plugin
settings, with owner-only permissions. Hand edits are overwritten on the next
session. To change credentials, use `/plugin` and configure
`defectdojo-connect`.

Environment variables take priority over the file: `DD_BASE_URL` and
`DD_API_TOKEN`. This is the supported path for CI and for anyone who will not
keep a credential on disk. A stale exported `DD_API_TOKEN` in a shell profile
silently overriding fresh plugin settings is worth checking when a token that
should be valid keeps failing. `dd-api config` names the source it used.

## What never to suggest

- Bypassing the Pro edition check. There is no supported way and it is not a bug.
- Pasting a token into the conversation.
- Editing the credential file by hand.
- Disabling TLS verification.

---
name: connection-doctor
description: Diagnose and repair the connection between Claude Code and DefectDojo Pro. Use when DefectDojo tools are missing or failing, when setting up or configuring DefectDojo for the first time, when a token is rejected or expired, when the user asks whether DefectDojo is connected or working, or when any other DefectDojo skill stops with a connection, authentication, permission, or edition error. Trigger even if the word DefectDojo never appears, for example "my security findings tools disappeared", "why do I get 401 from the vuln tracker", "the scanner database says forbidden", or a pasted "Token authentication failed" error.
---

# DefectDojo connection doctor

This plugin requires **DefectDojo Pro**. It does not support DefectDojo open
source and will refuse to run against it.

## Why this skill exists

Connection failures in this integration have five distinct causes that produce
similar looking symptoms, and guessing between them wastes the user's time:

1. Nothing is configured yet.
2. The instance is DefectDojo open source, which this plugin does not support.
3. The API token is wrong, revoked, or expired. DefectDojo tokens can expire.
4. The MCP server is disabled on the instance, so REST works but tools are missing.
5. The user's DefectDojo role does not permit the action, so everything works except one call.

Probe in order and stop at the first failure. Do not skip ahead: a missing tool
is a symptom of causes 1, 2 and 4 alike, and only the ordered probes separate them.

## Procedure

### Step 1: Establish what is configured

```
dd-api config
```

This prints the instance URL and where the credential came from. It never
prints the token. If it exits 3, nothing is configured: go to Step 6.

### Step 2: Verify credentials and edition together

```
dd-api whoami
```

Interpret the exit code. Do not interpret the text of an error you have not read.

| Exit | Meaning | What to tell the user |
|------|---------|----------------------|
| 0 | Credentials and edition are good | Continue to Step 3 |
| 3 | Not configured | Go to Step 6 |
| 4 | Token rejected or forbidden | Go to Step 5 |
| 5 | Not a Pro instance, or the Pro API is unreachable | Go to Step 4 |
| 6 | HTTP or network failure | Report the status and URL; check VPN, proxy, and that the URL has no trailing path |

### Step 3: Check the MCP server itself

REST working does not mean the MCP tools are available. They are separately
gated on the instance.

Check whether MCP tools are present in this session. The DefectDojo tools are
named `mcp__defectdojo__*`, for example `mcp__defectdojo__get_products`. Try one
small call, such as `get_products` with `limit` 1.

If REST succeeded but the MCP tools are missing or erroring:

- The MCP server may be disabled on the instance. A DefectDojo administrator
  enables it under the AI settings in the Pro UI. It is a live toggle and needs
  no restart. Self-hosted deployments also need `MCP_ENABLED` set at deploy time.
- The session may predate the configuration. MCP servers connect at session
  start, so tell the user to start a new session after any credential change.
- Report `dd-api feature-flags` output only if the user is debugging a specific
  feature, not as routine noise.

### Step 4: Edition failures

Exit code 5 means the Pro-only API surface is absent. State plainly that the
plugin requires DefectDojo Pro and does not work with DefectDojo open source.
Do not offer a workaround, a reduced mode, or a way to bypass the check. There
is none by design.

Before concluding, confirm two things that produce the same symptom:

- The URL points at the DefectDojo application root, with no trailing path and
  no `/api/v2` suffix. `https://example.cloud.defectdojo.com` is right,
  `https://example.cloud.defectdojo.com/api/v2/` is not.
- A proxy or SSO gateway is not intercepting the request and returning its own
  404. If the user can load the DefectDojo UI in a browser but the probe 404s,
  suspect the gateway.

If the user wants Pro, point them at a two-week SaaS trial at defectdojo.com.

### Step 5: Token failures

Exit code 4 covers two different problems. Read the message.

- **401 rejected**: the token is wrong, revoked, or expired. DefectDojo tokens
  can expire, and the failure appears mid-session with no warning. The user
  generates a fresh API v2 key from their DefectDojo user profile, then updates
  it through `/plugin` by configuring `defectdojo-connect`, then starts a new
  session. Never retry the same token, and never suggest pasting the token into
  the chat.
- **403 forbidden**: the token is valid but the user's role does not allow that
  operation on that object. Name the object and the operation, and say which
  role level is needed. Suggest performing it as a user who has the role rather
  than escalating the token.

### Step 6: First-time setup

Tell the user exactly this sequence:

1. In DefectDojo, open your user profile and create an API v2 key.
2. In Claude Code, run `/plugin`, choose `defectdojo-connect`, and configure it.
   Enter the instance URL, for example `https://yourcompany.cloud.defectdojo.com`,
   with no trailing slash and no path. Paste the API key when prompted. It is
   stored in the operating system keychain.
3. Start a new session so the MCP server connects and the credentials load.
4. Run this doctor again to confirm.

For CI or for users who will not keep a credential on disk, both values can come
from the environment instead: `DD_BASE_URL` and `DD_API_TOKEN`.

## Rules

- Never ask the user to paste their API token into the conversation, and never
  echo one if they do. If a token appears in the transcript, tell them to revoke
  it and issue a new one.
- Never suggest editing `~/.defectdojo/claude-code.json` by hand. It is written
  from plugin settings at session start and hand edits are overwritten.
- Never propose bypassing the Pro edition check.
- Report what each probe actually returned. Do not assert that something is
  fixed until a probe confirms it.

## Reference

`references/troubleshooting.md` covers proxies, self-hosted nginx, self-signed
certificates, and the difference between the deploy-time and runtime MCP toggles.
Read it when the fast path above does not resolve the failure.

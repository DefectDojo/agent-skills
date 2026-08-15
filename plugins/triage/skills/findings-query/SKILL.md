---
name: findings-query
description: Answer questions about DefectDojo security findings, products, engagements, tests, and risk posture, and produce a security brief. Use for questions like how many critical findings are open, what is our riskiest application, show me open SQL injection findings, what changed this week, which product has the worst backlog, what should we fix first, give me a security summary for standup, or top CWEs. Trigger even if the word DefectDojo never appears whenever the user asks about vulnerabilities, findings, scan results, security posture, or a security backlog and DefectDojo tools are available. Read-only, never changes finding state.
---

# Query DefectDojo findings

This plugin requires **DefectDojo Pro**.

## Why this skill exists

Three failure modes make naive answers here worse than no answer:

1. **Invented numbers.** Every count, severity and name must come from a tool
   call in this session. Never estimate, never carry a number over from earlier
   in the conversation without refetching if the user asked again.
2. **Unstated basis.** DefectDojo can be configured to count only verified
   findings. A count that does not say what it counted will be contradicted by
   the UI and destroy trust in the whole integration.
3. **Wrong tool for the question.** The MCP tools cover most reads but cannot
   order by priority. Reaching for the wrong one produces a confidently wrong
   "top" list.

This skill is read-only. If the user asks to change anything, hand off to the
triage-findings skill instead.

## Choosing the tool

Prefer MCP tools. They are purpose-built, token-efficient, and already scoped to
the user's permissions.

| Question shape | Use |
|---|---|
| List or filter findings | `mcp__defectdojo__get_findings` |
| One finding in detail | `mcp__defectdojo__get_finding_by_id` |
| Counts, severity spread, average age, top CWEs | `mcp__defectdojo__finding_summary` |
| Risk posture for one product | `mcp__defectdojo__risk_summary` |
| Products, and their criticality or platform | `mcp__defectdojo__get_products` |
| Product categories | `mcp__defectdojo__get_product_types` |
| Engagements or tests | `mcp__defectdojo__get_engagements`, `mcp__defectdojo__get_tests` |
| Users, groups, roles, membership | `mcp__defectdojo__get_users`, `get_user_by_id`, `get_groups`, `get_group_by_id`, `get_dojo_group_members`, `get_roles` |
| **Ranked by priority, or filtered by file path or component** | `dd-api` (see below) |

### When to fall back to dd-api

`get_findings` cannot sort. For anything phrased as "top", "worst", "highest
risk", or "what should we fix first", use the REST API through `dd-api`, which
supports priority ordering and priority bounds:

```
dd-api get "/api/v2/findings/?active=true&limit=10&o=-priority"
dd-api get "/api/v2/findings/?active=true&priority_min=80&limit=25&o=-priority"
dd-api get "/api/v2/findings/?test__engagement__product=5&active=true&o=-priority&limit=10"
```

Priority is DefectDojo's own ranking. It weighs exploitability, threat
intelligence, reachability, business context and many more signals. When you
present a ranked list, say that DefectDojo ranks on risk rather than on severity
alone, and never present a closed list of the factors as if it were complete.

`references/filter-cookbook.md` has the exact parameter names and values for
both channels. Read it before constructing anything beyond a simple query.

## Procedure

1. **Resolve names to identifiers first.** Users say "the payments app", the API
   wants a product id. Call `get_products` with a name filter, and if more than
   one plausibly matches, ask which one rather than guessing.
2. **Fetch.** Prefer one summary call over many detail calls. `finding_summary`
   answers most "how many" questions in a single call.
3. **State the basis.** If the instance enforces verified status, summary counts
   cover verified findings only. Say which basis you used in one short clause,
   for example "counting active verified findings".
4. **Present.** Severity order is Critical, High, Medium, Low, Info. Use a
   compact table for more than three findings, prose for fewer. Include the
   finding id, because every other skill takes ids.
5. **Link.** Add deep links with `dd-link finding <id>` or
   `dd-link findings-open <product id>` so a human can open the object.
6. **Offer the next step, do not take it.** If findings clearly need triage, say
   so and let the user ask.

## Brief mode

When the user asks for a brief, standup summary, morning update, or "what
changed", follow this fixed recipe so consecutive briefs are comparable:

1. `finding_summary` scoped to the period, using the `date` parameter, for the
   headline counts by severity.
2. New findings in the period: `get_findings` with the same `date` value and
   `status` of Active.
3. The top few by priority through `dd-api` with `o=-priority`.
4. Anything in Under Review or Risk Accepted worth a mention.

Keep it short enough to read out loud. Lead with what changed, not with totals
that did not move.

## Rules

- Read-only. Never call a write endpoint from this skill, and never pass
  `--data` to `dd-api` here.
- Never invent a count, a severity, a CWE, a product name, or a finding title.
- If a tool call fails with a connection, authentication, permission, or edition
  error, stop and run the connection doctor instead of retrying blindly.
- Do not paginate endlessly. Ask for a narrower question when a result set is
  large, and say how many you fetched out of how many exist.

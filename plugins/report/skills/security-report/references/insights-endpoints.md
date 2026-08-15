# Insights endpoints

DefectDojo Pro exposes several insight collections that back the reporting
views. They are read-only and each is a set of GET actions.

Discover the exact actions and their parameters on the instance you are talking
to rather than assuming, because they vary by version:

```
dd-api get "/api/v2/oa3/schema/?format=json" | grep -o '"/api/v2/[a-z_]*insights[^"]*"' | sort -u
```

That is authoritative for the instance. The notes below describe what each
collection is for.

## The collections

| Collection | Answers |
|---|---|
| `executive_insights` | Overall posture, the top-level numbers for a leadership audience |
| `priority_insights` | Where risk concentrates, by DefectDojo's own priority ranking |
| `program_insights` | Program health over time: intake against closure, aging, coverage |
| `remediation_insights` | Fix throughput, time to remediate, trend |
| `tool_insights` | Which scanners are reporting, coverage and overlap between them |

## Choosing by audience

| Audience | Primary | Supporting |
|---|---|---|
| Board or executive | `executive_insights` | `remediation_insights` for the trend |
| Engineering leadership | `program_insights` | `priority_insights`, per-product `risk_summary` |
| Audit or compliance | `program_insights` | `tool_insights` for coverage evidence |

## Per-product color

The MCP tools fill in specifics the insight collections do not:

- `mcp__defectdojo__risk_summary` with a `product_id`: posture for one product.
- `mcp__defectdojo__finding_summary` with `product_id` or `engagement_id` and a
  `date`: counts by severity, average age, top CWEs.

## Native report generation

When the output has to be an artifact from the security tool of record rather
than a document written in the conversation:

```
dd-api post /api/v2/generated_reports/quick_report/ --data '{...}'
dd-api get /api/v2/generated_reports/<id>/
dd-api get /api/v2/generated_reports/<id>/download
```

Generation is asynchronous. The create call returns immediately; poll the
detail endpoint until the status is completed, then offer the download. Do not
hand over a download link before then.

Related collections for customized output: `report_templates`, `report_blocks`,
`report_themes`.

## Trends

A trend needs two fetched points. If you have only the current period, report
the current state and say the comparison was not available. Do not derive a
direction from a single number, and do not describe movement you did not
measure.

## Talking about prioritization

DefectDojo ranks on risk, weighing exploitability, threat intelligence,
reachability, business context and many more signals. Name a few and say there
are more rather than presenting a closed list, and never equate severity with
risk in a report: a critical severity finding that is unreachable can matter
less than a high severity one on an internet-facing path.

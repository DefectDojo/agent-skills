# Filter cookbook

Exact parameter names and values for both read channels. Values are
case-sensitive and must match precisely.

## MCP tools

### get_findings

| Parameter | Type | Values |
|---|---|---|
| `limit` | number | minimum 1, default 100 |
| `offset` | number | minimum 0 |
| `severity` | array of strings | `Critical`, `High`, `Medium`, `Low`, `Info` |
| `status` | array of strings | `Any`, `Active`, `Open`, `Verified`, `Out of Scope`, `False Positive`, `Inactive`, `Risk Accepted`, `Closed`, `Under Review` |
| `date` | array of strings | `0 - Any date`, `1 - Today`, `2 - Past 7 days`, `3 - Past 30 days`, `4 - Past 90 days`, `5 - Current month`, `6 - Current year`, `7 - Past year` |
| `product_id` | number | |
| `engagement_id` | number | |
| `test_id` | number | |

The `date` values include their numeric prefix. `"2 - Past 7 days"` is the whole
string, not `2` and not `"Past 7 days"`.

There is no sort parameter. For ranked output use the REST API.

### get_products

| Parameter | Type | Values |
|---|---|---|
| `limit`, `offset` | number | |
| `name` | string | |
| `business_criticality` | array | `Very High`, `High`, `Medium`, `Low`, `Very Low` |
| `platform` | array | `API`, `Desktop`, `Internet of Things`, `Mobile`, `Web` |
| `lifecycle` | array | `Construction`, `Production`, `Retirement` |
| `external_audience` | string | `"true"` or `"false"`, as strings |
| `internet_accessible` | string | `"true"` or `"false"`, as strings |

The two booleans are strings by design. Passing real booleans fails.

### Summaries

- `finding_summary`: `engagement_id`, `product_id`, `date` (same values as
  above). Returns counts by severity, average priority and risk score, average
  age, and top CWEs.
- `risk_summary`: `product_id`. Returns posture for one product.

### Everything else

`get_finding_by_id` takes `finding_id`. `get_user_by_id` takes `user_id`.
`get_group_by_id` takes `group_id`. `get_dojo_group_members` takes `group_id`
and optionally `user_id`. `get_engagements`, `get_tests`, `get_product_types`
and `get_roles` take only `limit` and `offset`. `get_users` also takes
`username`, `email`, `is_active` and `is_superuser`, the last two as the strings
`"true"` or `"false"`.

## REST through dd-api

Use this channel when you need priority bounds, ordering by a supported field,
or a filter the MCP tools do not expose.

### Ranking

```
dd-api get "/api/v2/findings/?active=true&priority_min=80&limit=50"
```

`priority` is DefectDojo's computed risk ranking, a number where higher means
fix sooner. `priority_min` and `priority_max` bound it, and both are Pro-only.
The response carries `priority` on every finding: order the page by it yourself
before presenting, descending.

`o` is the ordering parameter for other fields (`-` prefix for descending),
for example `o=-created` or `o=numerical_severity`. `priority` is **not** an
accepted `o` value and returns HTTP 400. `ordering=` and `sort=` are not
parameters at all and are silently ignored.

### Common filters

| Parameter | Notes |
|---|---|
| `active`, `verified`, `false_p`, `duplicate`, `is_mitigated`, `out_of_scope`, `under_review`, `risk_accepted` | booleans as `true` or `false` |
| `severity` | single value; repeat the parameter for several |
| `title`, `component_name`, `file_path`, `description` | substring matching via the `__icontains` variants |
| `test__engagement__product` | product id, the usual way to scope to one product |
| `test__engagement` | engagement id |
| `tags` | tag name |
| `vulnerability_id` | CVE or equivalent |
| `limit`, `offset` | pagination |

### Worked examples

Top ten by risk across the program (fetch the high band, then order by
`priority` yourself and keep the first ten):

```
dd-api get "/api/v2/findings/?active=true&priority_min=80&limit=50"
```

Everything critical and unverified in one product:

```
dd-api get "/api/v2/findings/?test__engagement__product=5&severity=Critical&verified=false&active=true"
```

Findings that mention a component:

```
dd-api get "/api/v2/findings/?component_name__icontains=lodash&active=true"
```

High priority only, newest first (a supported ordering combined with the
Pro-only bound):

```
dd-api get "/api/v2/findings/?priority_min=80&active=true&o=-created"
```

## Counting basis

DefectDojo can be configured to enforce verified status, in which case summary
counts include only verified findings. A count taken with `active=true` alone
and a count from `finding_summary` can legitimately differ for this reason.

Always state the basis in the answer. One clause is enough: "counting active
verified findings".

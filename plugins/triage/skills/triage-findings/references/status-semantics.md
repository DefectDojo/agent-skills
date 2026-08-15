# Finding status semantics

What each state means, when it is correct, and how to set it. Choosing the wrong
one misleads auditors and confuses DefectDojo's deduplication on the next scan.

## The states

| State | Means | Use when |
|---|---|---|
| Active | Open and counted in the backlog | Default for a real, unresolved finding |
| Verified | A human confirmed it is real | Someone actually reviewed it, not merely that a command succeeded |
| Mitigated (closed) | The underlying issue was fixed | The vulnerability is genuinely resolved |
| False positive | The scanner was wrong | The reported issue does not exist as described |
| Out of scope | Real, but not in scope for this assessment | Test fixtures, vendored code, a deliberately excluded path |
| Risk accepted | Real, understood, accepted by an owner | There is an actual acceptance decision, ideally with an owner and an expiry |
| Under review | Being triaged | Parked pending a decision |
| Duplicate | The same issue as another finding | Another finding is the original |

False positive and out of scope are frequently confused. False positive means
the scanner was wrong. Out of scope means the scanner was right and you do not
care in this context. Auditors read them very differently.

Risk accepted is not a synonym for "we are not fixing it". It is a recorded
decision. If nobody has made that decision, the finding is not risk accepted.

## Setting each state

Two custom actions exist. Everything else is a field update.

```
dd-api close-finding <id> --note "Fixed in 1.4.2, verified against the patched build"
dd-api verify-finding <id>
```

Field updates through PATCH:

```
# False positive
dd-api patch /api/v2/findings/<id>/ --data '{"false_p": true, "active": false}'

# Out of scope
dd-api patch /api/v2/findings/<id>/ --data '{"out_of_scope": true, "active": false}'

# Under review
dd-api patch /api/v2/findings/<id>/ --data '{"under_review": true}'

# Reopen
dd-api patch /api/v2/findings/<id>/ --data '{"active": true, "is_mitigated": false, "false_p": false}'
```

Set `active` to false alongside `false_p` or `out_of_scope`. Leaving it true
keeps the finding in the open backlog, which is almost never intended and is a
common source of "I marked it and it is still there".

## Notes

```
dd-api note <id> "text"
```

Every state change gets one. Write what a colleague would need six months later:
what was decided, on what evidence, and by whom. Mentioning that the change came
through Claude Code is useful provenance.

## Tags

```
dd-api post /api/v2/findings/<id>/tags/ --data '{"tags": ["reviewed-2026-q3"]}'
dd-api patch /api/v2/findings/<id>/remove_tags/ --data '{"tags": ["needs-triage"]}'
```

Tags are additive on POST. To replace the whole set, patch the finding's `tags`
field directly.

## Risk acceptance

Simple acceptance is a field on the finding:

```
dd-api patch /api/v2/findings/<id>/ --data '{"risk_accepted": true, "active": false}'
```

DefectDojo also has first-class risk acceptance objects that carry an owner,
expiry and proof, which is what an audit will expect for anything material. This
is also the only genuine bulk write in the API:

```
dd-api post /api/v2/findings/accept_risks/ --data '{"risk_acceptance": <id>, "findings": [1,2,3]}'
```

Related endpoints: `/api/v2/risk_acceptance/`, plus `expire/`, `reinstate/` and
`download_proof/` actions on an individual acceptance.

## Duplicates

DefectDojo tracks duplicate clusters itself. Prefer its own operations over
closing duplicates by hand:

```
dd-api get /api/v2/findings/<id>/duplicate/
dd-api post /api/v2/findings/<id>/duplicate/reset/
dd-api post /api/v2/findings/merge/ --data '{...}'
```

Marking a duplicate as a false positive is wrong. The finding is real, it is
simply already recorded elsewhere.

## No bulk status endpoint

Other than `accept_risks`, there is no bulk write. Changing fifty findings means
fifty requests. Tell the user before starting a large run, and report progress
as you go.

## What survives the next scan

Closing a finding does not change the code. If the next scan still detects the
issue, DefectDojo may reactivate it. That is the system working correctly, but
it surprises people, so say it when closing something that was not actually
fixed.

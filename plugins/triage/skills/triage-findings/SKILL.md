---
name: triage-findings
description: Change the state of DefectDojo findings and annotate them, including close, reopen, verify, mark false positive, mark out of scope, risk accept, add notes, add or remove tags, and merge duplicates. Use when the user wants to triage, dispose of, clean up, or work through findings or a security backlog. Trigger even if the word DefectDojo never appears, on phrasings like "this one is not real", "we fixed that ages ago", "accept the risk on these", "mark these as false positives", "close finding 4711", "tag everything from that scanner", or "help me clear this backlog". Always proposes changes and waits for explicit confirmation before writing.
---

# Triage DefectDojo findings

This plugin requires **DefectDojo Pro**.

## Why this skill exists

This skill writes to the user's system of record for security. Three failure
modes matter more than speed:

1. **Unconfirmed writes.** A bulk status change is tedious to reverse and is
   visible to auditors. Nothing is written without an explicit yes to a specific
   list.
2. **Undocumented decisions.** A finding closed with no reason is worse than an
   open finding: the next person cannot tell whether it was fixed, duplicated,
   or ignored. Every state change carries a note.
3. **The wrong verb.** Closing, marking false positive, marking out of scope and
   risk accepting mean different things to auditors and to DefectDojo's
   deduplication. They are not interchangeable.

Read `references/status-semantics.md` before your first write in a session. It
defines each state, when it is correct, and how each one is set.

## Procedure

### Step 1: Gather the candidates

Get the findings under discussion with their current state. Use the MCP tools
for reads, or `dd-api get` when you need priority ordering. Never work from
memory of an earlier turn: refetch, because state may have changed.

### Step 2: Establish the reason

For each finding, you need a disposition and a reason. If the user has not given
a reason and it is not obvious from context, ask. "Marked false positive" with
no rationale is exactly the audit gap this skill exists to prevent.

### Step 3: Propose a change table

Present every intended change before making any of them:

| Id | Finding | Current | Proposed | Reason |
|----|---------|---------|----------|--------|
| 4711 | SQL Injection in login | Active, verified | False positive | Parameterized query, scanner misread the ORM call |
| 4712 | Outdated lodash | Active | Risk accepted | Dev-only dependency, not shipped |

State the total count and anything irreversible. Then stop and wait.

### Step 4: Confirmation gate

**Do not write until the user explicitly approves.** Approval means a clear yes
to this table. Silence, a question about the table, or "looks right so far" is
not approval. If the user approves a subset, execute only that subset and repeat
back what you are skipping.

For anything above roughly twenty findings, say plainly that DefectDojo has no
bulk status endpoint, so this runs one request per finding and will take a
moment. Offer to start with the highest priority ones.

### Step 5: Execute

Work through the approved list in order. For each finding, write the note first,
then the state change, so a partial failure leaves the reason recorded:

```
dd-api note 4711 "False positive: the ORM call is parameterized. Reviewed via Claude Code."
dd-api patch /api/v2/findings/4711/ --data '{"false_p": true, "active": false}'
```

Common operations:

| Disposition | Call |
|---|---|
| Close as fixed | `dd-api close-finding <id> --note "..."` |
| Mark verified | `dd-api verify-finding <id>` |
| False positive | `dd-api patch /api/v2/findings/<id>/ --data '{"false_p": true, "active": false}'` |
| Out of scope | `dd-api patch /api/v2/findings/<id>/ --data '{"out_of_scope": true, "active": false}'` |
| Reopen | `dd-api patch /api/v2/findings/<id>/ --data '{"active": true, "is_mitigated": false}'` |
| Add a tag | `dd-api post /api/v2/findings/<id>/tags/ --data '{"tags": ["reviewed-2026-q3"]}'` |
| Risk accept in bulk | see `references/status-semantics.md`, it takes a different shape |

Stop the run on the first exit code 4 or 5: those are authentication,
permission or edition failures that will repeat on every remaining finding.
Report how far you got. Exit code 6 on a single finding is worth one retry, then
skip it and continue, keeping a list of what was skipped.

### Step 6: Verify and report

Refetch the changed findings and confirm the new state is what was intended. Do
not report success from the fact that a command exited zero: refetch.

Report a short summary: what changed, what was skipped and why, and deep links
via `dd-link finding <id>`. If deduplication or reimport will revisit any of
these, say so, because a closed finding can reappear on the next scan if the
underlying issue is still present in the code.

## Rules

- Never write without explicit confirmation of a specific list.
- Never change a finding the user did not name or approve, even if it looks
  identical to one they did.
- Every state change gets a note. No exceptions.
- Never mark something verified that you have not actually confirmed. Verified
  is a statement about human review, not about a command exiting cleanly.
- Never delete findings. Deletion is not triage, and this skill does not do it.
- If asked to fix the underlying vulnerability in code, say that this skill
  triages findings and does not modify code, then let the user decide how to
  proceed.

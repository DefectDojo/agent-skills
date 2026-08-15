# defectdojo-triage

Ask about your findings in plain language, then act on them.

## Skills

**`findings-query`** answers questions and builds briefs. Read-only.

> How many criticals are open in the payments app?
> What are the top 10 things we should fix first?
> Give me a security brief for standup.

Counts come from the API and always state their basis. Ranked questions use
priority ordering, because DefectDojo ranks on risk rather than severity alone.

**`triage-findings`** changes finding state: close, verify, false positive, out
of scope, risk accept, notes, tags, duplicates.

> Findings 4711 and 4712 are false positives, the scanner misreads our ORM.

It always proposes a change table first and waits for explicit confirmation.
Every state change carries a note recording why, because an undocumented
disposition is an audit gap.

DefectDojo has no bulk status endpoint other than risk acceptance, so large runs
are one request per finding. The skill says so before starting.

Requires DefectDojo Pro and `defectdojo-connect`, which installs automatically.

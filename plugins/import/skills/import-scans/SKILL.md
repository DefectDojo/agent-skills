---
name: import-scans
description: Upload scanner output or an SBOM into DefectDojo Pro. Use when the user has results from a security scanner and wants them in DefectDojo, or says import this scan, upload these results, push the Semgrep or Trivy or ZAP or Snyk or Nuclei or Burp output to Dojo, ingest this SBOM or CycloneDX or SPDX file, or reimport the latest scan. Trigger even if the word DefectDojo never appears, for example "get these scan results into our vulnerability tracker" or "load this JSON from the scanner". Handles product and engagement creation, import versus reimport, and background processing.
---

# Import scans into DefectDojo

This plugin requires **DefectDojo Pro**.

## Why this skill exists

Four things go wrong with scan import, and all four are silent:

1. **Import when reimport was correct.** Import creates a new test every time.
   For a scan that runs repeatedly, that breaks the fixed-and-reappeared
   lifecycle and inflates the backlog. Reimport into the same test is almost
   always what a recurring scan wants.
2. **Wrong scan type.** DefectDojo has hundreds of parsers and picks none of
   them by guessing. A wrong type either errors or, worse, parses badly.
3. **Assuming the import was synchronous.** DefectDojo Pro may process in the
   background, and the instance setting can force that regardless of what the
   request asked for. Reporting "done" when processing has not finished produces
   confidently wrong counts.
4. **Silent context creation.** Auto-created products and engagements are real
   objects in the user's system of record. Creating them without saying so
   leaves clutter nobody can explain later.

## Procedure

### Step 1: Identify the scan type

Look at the file. `references/scan-types.md` maps common scanner output shapes
to their exact DefectDojo `scan_type` string, which must match precisely.

If you cannot identify it confidently, ask rather than guess. If DefectDojo
rejects the type, its error lists the valid choices: read that list and correct
the value rather than retrying variations.

### Step 2: Decide import or reimport

| Situation | Use |
|---|---|
| First time these results land in DefectDojo | import |
| A scan that runs repeatedly against the same target | reimport |
| The user names an existing test | reimport into that test |
| A one-off audit or a genuinely new target | import |

Reimport is the better default for anything from CI. It closes findings that no
longer appear, reactivates ones that came back, and leaves untouched findings
alone. Explain that in one sentence when you choose it.

### Step 3: Establish the context

Findings live under a product, then an engagement, then a test. Ask which
product unless the user has said. To create the hierarchy on the fly, pass
`--auto_create_context true` along with the names.

Say explicitly which product and engagement you are creating or writing into
before you run the import.

### Step 4: Run the import

```
dd-api import --file ./semgrep.json \
  --scan-type "Semgrep JSON Report" \
  --product-name "Payments API" \
  --engagement-name "CI scans" \
  --auto_create_context true
```

Reimport takes the same shape:

```
dd-api reimport --file ./semgrep.json \
  --scan-type "Semgrep JSON Report" \
  --product-name "Payments API" \
  --engagement-name "CI scans" \
  --auto_create_context true
```

Any DefectDojo API parameter can be passed as `--name value`, for example
`--close_old_findings true`, `--minimum_severity Medium`, `--branch_tag main`,
`--commit_hash abc123`, `--service checkout`.

`dd-api` handles the synchronous and background cases for you. When DefectDojo
processes in the background, it polls until the test reaches Processed or
Failed, up to ten minutes. Use `--no-poll` if the user wants to fire and forget,
and `--timeout <seconds>` for a very large scan.

Never claim the import finished if `dd-api` reported a timeout. That exit means
processing is still running on the server, not that it failed.

### Step 5: Report

Report the created, closed and reactivated counts if DefectDojo returned them,
and always report the test link with `dd-link test <id>`. If findings were
closed because they no longer appear in the scan, say so, because that is a real
change to the backlog that someone may need to explain.

## SBOM import

SBOM files use a different endpoint with its own status polling:

```
dd-api post /api/v2/sbom-import/ ...
dd-api get /api/v2/sbom-import/status/<task id>/
```

Read `references/scan-types.md` for the SBOM section before using it.

## Rules

- Never invent a `scan_type`. It must come from the reference or from the API's
  own list of valid choices.
- Never auto-create a product or engagement without telling the user first.
- Branch on what the response says about background processing, never on what
  was requested.
- Report counts only from the API response, never estimated from the file.
- If the file is large enough that upload will be slow, say so before starting
  rather than appearing to hang.

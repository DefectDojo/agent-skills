---
name: wire-ci-import
description: Add DefectDojo scan upload to a repository's CI pipeline. Use when the user wants scan results pushed to DefectDojo automatically on every build or pull request, asks to add DefectDojo to GitHub Actions or GitLab CI or Jenkins, wants to automate scan upload, or wants their pipeline wired into their vulnerability tracker. Trigger on phrasings like "send our scans to Dojo from CI", "automate this upload", "add this to our pipeline", or "I do not want to run this by hand every time". Edits pipeline files in the repository and sets up the API token as a CI secret.
---

# Wire DefectDojo import into CI

This plugin requires **DefectDojo Pro**.

## Why this skill exists

CI import is where a DefectDojo deployment either becomes the system of record
or quietly rots. Three mistakes cause the rot:

1. **Import instead of reimport.** In CI this compounds on every build: a new
   test per run, findings never closing, a backlog that only grows.
2. **A personal token in CI.** Personal tokens expire and are tied to one
   human's account and permissions. When that person's access changes, the
   pipeline breaks in a way nobody connects to the cause.
3. **A token committed in plain text.** It ends up in the repository, in logs,
   and in every fork.

## Procedure

### Step 1: Detect the CI system

Look for pipeline files in the repository: `.github/workflows/*.yml` for GitHub
Actions, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/config.yml`,
`azure-pipelines.yml`, `bitbucket-pipelines.yml`. If several exist, ask which
one is authoritative rather than editing all of them.

If no scanner runs in CI yet, say so. There is nothing to upload until a scanner
produces output, and wiring the upload first creates a step that always fails.

### Step 2: Find the scan step and its output file

Identify which step produces scanner output and the exact path it writes. The
upload step goes immediately after it, and must run even when the scan step
reports findings. In GitHub Actions that means `if: always()` on the upload
step, otherwise a failing scan silently stops results from reaching DefectDojo.

### Step 3: Propose the change

Show the diff you intend to make before editing. Name the file, the position of
the new step, and the secret that has to exist. Then wait for the user to agree.

`references/github-actions.md` has the full snippet. It uses reimport with
`auto_create_context`, and passes branch, commit and build metadata so findings
in DefectDojo trace back to the exact build.

The shape of the call, for any CI system:

```
curl -sS -X POST "$DD_URL/api/v2/reimport-scan/" \
  -H "Authorization: Token $DD_API_TOKEN" \
  -F "scan_type=Semgrep JSON Report" \
  -F "file=@semgrep.json" \
  -F "product_name=Payments API" \
  -F "engagement_name=CI scans" \
  -F "auto_create_context=true" \
  -F "background_import=true" \
  -F "branch_tag=$BRANCH" \
  -F "commit_hash=$COMMIT"
```

`background_import=true` is right for CI: the pipeline should not wait for
DefectDojo to finish processing.

### Step 4: Set up the token

Tell the user to create the secret in their CI system's own secret store, and
name it `DD_API_TOKEN`. Never write a token into a pipeline file, never echo it
in a step, and never ask the user to paste it into the conversation.

Recommend a service account rather than a personal token: a dedicated
DefectDojo user with only the permissions needed to import into the relevant
products. Personal tokens expire and carry one person's access, which is the
usual cause of a pipeline that worked for months and then stopped.

Also needed: `DD_URL` as a plain variable, which is not secret.

### Step 5: Verify

You cannot run their CI from here. Say exactly how the user verifies:

1. Push the branch and let one build run.
2. Confirm the upload step succeeded in the build log.
3. Open the engagement in DefectDojo and confirm a new test appeared with
   findings from that build.

Offer to run the same import locally once with `import-scans` so the product and
engagement exist and the credentials are proven before CI depends on them.

## Rules

- Reimport, not import, unless the user has a specific reason.
- Never write a credential into a repository file.
- Never edit a pipeline file without showing the change first.
- Do not claim the pipeline works. You cannot observe their CI. Describe what
  the user should see.

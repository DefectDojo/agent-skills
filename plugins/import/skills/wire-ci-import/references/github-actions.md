# CI snippets

Reimport, not import, in every one of these. See the import-scans skill for why.

## GitHub Actions

Add after the step that produces scanner output. `if: always()` matters: without
it, a scan step that exits non-zero because it found something stops the results
from ever reaching DefectDojo.

```yaml
      - name: Upload results to DefectDojo
        if: always()
        env:
          DD_URL: ${{ vars.DD_URL }}
          DD_API_TOKEN: ${{ secrets.DD_API_TOKEN }}
        run: |
          curl -sS --fail-with-body -X POST "$DD_URL/api/v2/reimport-scan/" \
            -H "Authorization: Token $DD_API_TOKEN" \
            -F "scan_type=Semgrep JSON Report" \
            -F "file=@semgrep.json" \
            -F "product_name=${{ github.event.repository.name }}" \
            -F "engagement_name=CI" \
            -F "auto_create_context=true" \
            -F "background_import=true" \
            -F "branch_tag=${{ github.ref_name }}" \
            -F "commit_hash=${{ github.sha }}" \
            -F "build_id=${{ github.run_id }}"
```

Set the secret with `gh secret set DD_API_TOKEN`, and `DD_URL` as a repository
variable since it is not sensitive.

## GitLab CI

```yaml
upload-to-defectdojo:
  stage: test
  when: always
  script:
    - |
      curl -sS --fail-with-body -X POST "$DD_URL/api/v2/reimport-scan/" \
        -H "Authorization: Token $DD_API_TOKEN" \
        -F "scan_type=Semgrep JSON Report" \
        -F "file=@semgrep.json" \
        -F "product_name=$CI_PROJECT_NAME" \
        -F "engagement_name=CI" \
        -F "auto_create_context=true" \
        -F "background_import=true" \
        -F "branch_tag=$CI_COMMIT_REF_NAME" \
        -F "commit_hash=$CI_COMMIT_SHA" \
        -F "build_id=$CI_PIPELINE_ID"
```

`DD_API_TOKEN` goes in the project's CI/CD variables, masked and protected.

## Jenkins

```groovy
stage('Upload to DefectDojo') {
  steps {
    withCredentials([string(credentialsId: 'defectdojo-api-token', variable: 'DD_API_TOKEN')]) {
      sh '''
        curl -sS --fail-with-body -X POST "$DD_URL/api/v2/reimport-scan/" \
          -H "Authorization: Token $DD_API_TOKEN" \
          -F "scan_type=Semgrep JSON Report" \
          -F "file=@semgrep.json" \
          -F "product_name=$JOB_NAME" \
          -F "engagement_name=CI" \
          -F "auto_create_context=true" \
          -F "background_import=true" \
          -F "branch_tag=$BRANCH_NAME" \
          -F "commit_hash=$GIT_COMMIT" \
          -F "build_id=$BUILD_NUMBER"
      '''
    }
  }
}
```

## Notes that apply everywhere

**Use a service account.** A dedicated DefectDojo user whose token belongs to
the pipeline, not to a person. Personal tokens expire and carry one individual's
permissions, so the pipeline breaks when their access changes and nobody
connects the two events.

**`background_import=true` in CI.** The pipeline should not wait for DefectDojo
to finish processing. The upload returns as soon as the file is accepted and
parsed.

**`--fail-with-body`** makes curl exit non-zero on an HTTP error while still
printing the response, so a failed upload fails the step visibly instead of
passing silently. On curl older than 7.76 use `--fail` and accept the loss of
the body.

**Never echo the token.** No `set -x` in a block that references it, and never
interpolate it into a log line.

**Product naming.** Deriving the product name from the repository name is
convenient but creates a new product for every repository. If the organization
already has a naming convention in DefectDojo, follow it instead.

## Verifying

1. Push a branch and let one build run.
2. Confirm the upload step succeeded in the build log.
3. Open the engagement in DefectDojo and confirm a new test with findings from
   that build, with the branch and commit recorded.

Running the same import once locally first, through the import-scans skill,
proves the credentials and creates the context before CI depends on it.

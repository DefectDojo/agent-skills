# Scan types

The `scan_type` value must match DefectDojo's parser name exactly, including
spaces and capitalization. DefectDojo supports several hundred parsers; the
table below covers what turns up most often in a repository.

## Identifying the file

| Shape of the file | Likely scanner |
|---|---|
| `{"results": [...]}` with `check_id` and `extra` | Semgrep |
| `{"Results": [...]}` with `Vulnerabilities` and `Target` | Trivy |
| `{"site": [...]}` with `alerts` | OWASP ZAP |
| `{"vulnerabilities": [...]}` with `identifiers` | GitLab scanners |
| `{"runs": [...]}` with `tool.driver` | Anything SARIF |
| `{"Issues": [...]}` with `issue_confidence` | Bandit |
| `{"vulnerabilities": [...]}` with `packageName` and `moduleName` | Snyk |
| `bomFormat` is `CycloneDX` | CycloneDX SBOM |
| `spdxVersion` present | SPDX SBOM |
| `{"matched-at": ...}` per line | Nuclei |
| XML with `<issues>` and `<issue>` | Burp Suite |

## Common scan_type values

| Scanner | scan_type |
|---|---|
| Semgrep | `Semgrep JSON Report` |
| Trivy | `Trivy Scan` |
| Trivy operator | `Trivy Operator Scan` |
| OWASP ZAP | `ZAP Scan` |
| Burp Suite | `Burp Scan` |
| Bandit | `Bandit Scan` |
| Snyk | `Snyk Scan` |
| npm audit | `NPM Audit Scan` |
| yarn audit | `Yarn Audit Scan` |
| Grype | `Anchore Grype` |
| Anchore | `Anchore Engine Scan` |
| Nuclei | `Nuclei Scan` |
| Checkov | `Checkov Scan` |
| tfsec | `Tfsec Scan` |
| Gitleaks | `Gitleaks Scan` |
| TruffleHog | `Trufflehog Scan` |
| Dependency Check | `Dependency Check Scan` |
| Dependency Track | `Dependency Track Finding Packaging Format (FPF) Export` |
| SonarQube | `SonarQube Scan` |
| Nessus | `Nessus Scan` |
| Qualys | `Qualys Scan` |
| Nmap | `Nmap Scan` |
| Kubescape | `Kubescape JSON Importer` |
| kube-bench | `kube-bench Scan` |
| Generic SARIF | `SARIF` |
| Anything else, mapped to the generic format | `Generic Findings Import` |

When several products share a family name, the exact string matters. If you are
not certain, do not guess: submit and read the error, which lists valid choices,
or ask the user.

## Validating without importing

If DefectDojo rejects a `scan_type`, the error enumerates the valid values.
Match against that list rather than trying variations. The list is authoritative
for the instance and its version, which the table here is not.

## SBOM import

SBOMs use their own endpoint rather than `import-scan`:

```
dd-api post /api/v2/sbom-import/ \
  --form "file=@sbom.json" \
  --form "product_name=Payments API" \
  --form "engagement_name=SBOM"
```

The response carries a task id. Poll it:

```
dd-api get /api/v2/sbom-import/status/<task id>/
```

CycloneDX and SPDX are both accepted. A CycloneDX file can alternatively go
through the normal import path with a CycloneDX scan type; the dedicated
endpoint is the better route when the SBOM is the point rather than one scan
among many.

## Useful parameters

| Parameter | Effect |
|---|---|
| `auto_create_context` | Creates product, engagement and test as needed |
| `product_type_name`, `product_name`, `engagement_name`, `test_title` | The context to create or write into |
| `minimum_severity` | Discards findings below this severity at import |
| `close_old_findings` | On reimport, closes findings absent from the new scan |
| `do_not_reactivate` | Leaves previously closed findings closed |
| `branch_tag`, `commit_hash`, `build_id` | Build provenance, valuable from CI |
| `service` | Distinguishes services inside one product |
| `apply_tags_to_findings` | Applies the import's tags to each finding |
| `background_import` | Requests background processing; the instance can force it regardless |
| `deduplication_on_engagement` | Scopes deduplication to the engagement |

## Import versus reimport

Import creates a new test on every call. Reimport writes into an existing test,
closing findings that no longer appear, reactivating ones that came back, and
leaving the rest alone.

For anything recurring, reimport is correct. Reimport with
`auto_create_context` will create the context on first run and then reuse it, so
the same command works for both the first run and every run after.

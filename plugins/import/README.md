# defectdojo-import

Get scanner output into DefectDojo, by hand or from CI.

## Skills

**`import-scans`** uploads scanner output or an SBOM.

> Get this semgrep.json into Dojo under the payments product.

It identifies the scan type, chooses import or reimport correctly (reimport for
anything recurring, so findings close and reactivate properly), creates the
product and engagement if asked, and handles background processing. DefectDojo
Pro may process in the background regardless of what the request asked for, so
the skill branches on what the response actually says and waits for the test to
finish before reporting counts.

**`wire-ci-import`** adds scan upload to your pipeline.

> Push our Semgrep results to DefectDojo from GitHub Actions.

Detects the CI system, proposes the diff before editing, uses reimport with
build provenance, and sets the token up as a CI secret. It recommends a service
account rather than a personal token, because personal tokens expire and carry
one person's permissions.

Requires DefectDojo Pro and `defectdojo-connect`, which installs automatically.

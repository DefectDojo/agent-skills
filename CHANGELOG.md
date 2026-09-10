# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html) with every plugin
released at the same version.

## [Unreleased]

## [1.0.0]

First release.

### Added

- `defectdojo` umbrella plugin, installing the full set in one command.
- `defectdojo-connect`: MCP server wiring, one-time credential entry, the
  `dd-api` REST bridge, the `dd-link` deep-link helper, and the
  `connection-doctor` skill.
- `defectdojo-triage`: `findings-query` for read-only questions and briefs,
  `triage-findings` for state changes behind a confirmation gate.
- `defectdojo-import`: `import-scans` with import versus reimport guidance and
  background-import polling, `wire-ci-import` for pipeline setup.
- `defectdojo-report`: `security-report` over the Pro insights endpoints, with
  native report generation.
- Enforced DefectDojo Pro requirement. The plugins refuse to run against
  DefectDojo open source rather than partially working.
- Behavioral test suite for `dd-api` covering the Pro path, open source refusal,
  expired credentials, and synchronous, background, and failing imports.
- Priority semantics check in `dd-api`: a findings query that asks for the
  Pro-only priority bound refuses an answer that carries no `priority` field,
  which is what open source returns because it ignores the parameter instead of
  rejecting it. A defeated edition check therefore fails loudly rather than
  presenting an unfiltered list as a ranked one.
- Ranking recipe verified against a live DefectDojo Pro instance: `priority` is
  not an accepted `o` ordering value (HTTP 400), so the skills bound with
  `priority_min` and order the page client-side. The test stub rejects
  `o=-priority` the same way the real API does.
- Import flags such as `--product-name` and `--scan-type` are sent to the API as
  `product_name` and `scan_type`. They were passed through verbatim, which the
  importer ignores before reporting the field as missing; found in the same live
  run. The stub now validates field names so the mapping cannot regress.

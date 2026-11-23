# Helm Charts

A collection of Helm charts for deploying applications on Kubernetes (`charts/home-information`, and
`charts/outline`, a fork of the archived lrstanley outline chart), tested with helm-unittest and released
via chart-releaser from GitHub Actions.

Spec-driven development is managed with **OpenSpec** (`openspec/`). All feature work flows through a
change in `openspec/changes/`.

## Project notes

### Binding decisions
- **Charts are independent.** Each lives in `charts/<name>/` and stands alone; a block touches one chart
  unless the change's `design.md` says otherwise.
- **The CHANGELOG owns the version.** The release workflow rewrites `version:` in `Chart.yaml` from the
  top `## [x.y.z]` heading of the chart's `CHANGELOG.md`. Never hand-edit `version:`; record changes under
  `## [Unreleased]`. (`charts/outline` has no CHANGELOG, so the workflow skips it.)
- **Tests are helm-unittest suites** in `templates/tests/*.yaml`; a template change ships with a suite
  asserting rendered output.
- **`charts/outline` is a fork** of the archived lrstanley/helm-charts outline chart. Keep divergence
  deliberate and noted; no drive-by reformatting.
- **No secrets in the repo.** Credentials in values, examples, tests and docs are placeholders only
  (`__snapshot__/` is gitignored).

### Hazards
- **Render across value combinations:** defaults, optional features/subcharts off, Ingress vs HTTPRoute;
  guard optional blocks, `required` for must-set values.
- **Upgrade safety:** generated credentials (`lookup`) must be stable across `helm upgrade`; watch immutable
  fields (selectors, PVC specs, Jobs), renamed resources, changed `fullname`.
- **values.yaml compatibility:** renamed/removed keys are breaking: CHANGELOG entry + deprecation path;
  new keys default so existing installs render unchanged.
- **Selector labels** from `_helpers.tpl` match across Deployment/Service/PDB/NetworkPolicy and never
  include version-varying values.
- **Subchart seam (`outline`: postgresql, redis, minio, dex):** parent overrides, `condition:` flags and
  generated credentials stay consistent with what the subcharts expect.
- **Helm limitation:** `helm lint` reports a render-time `fail` only as `[INFO]` (exit 0); `make lint` also
  `helm template`s every `examples/*.yaml` to catch it.

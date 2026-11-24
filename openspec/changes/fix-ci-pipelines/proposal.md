# Proposal

## Why

Both GitHub Actions pipelines are broken, and neither has been checked by a gate that matches what we run locally.

- **PR CI never runs.** Every `CI` run on a pull request (#1, #2) ended `startup_failure` with zero jobs. The cause was most likely the repo's Actions allow list blocking `azure/setup-helm`, the only action unique to `ci.yml`. That action is now allowed. Even once it starts, `ci.yml` only runs `helm lint` and `helm unittest`. It does not fetch subchart dependencies (so `charts/outline` cannot lint), does not run `make format`, and does not render the example values.
- **The release job fails on every merge to `main`.** `chart-releaser` runs `cr package` on `charts/outline` and aborts with `no repository definition for https://charts.bitnami.com/bitnami ... https://charts.dexidp.io`, because the runner has no `helm repo add` entries. The last green release predates the outline fork. As a result `prometheus-pve-exporter` 0.1.0 (merged in #2) has not been released.

## What Changes

- **CI** (`.github/workflows/ci.yml`) runs the repo's own gates through the `Makefile` instead of ad-hoc `helm` commands: `make lint test format`. It installs Helm and helmfmt at pinned versions, and the helm-unittest plugin (pinned) via `make init`. The `validate` gate is deliberately left out: it needs the `openspec` CLI and fails whenever `openspec/changes/` has no active change, which would fail every PR once this and the pve-exporter change are archived. `validate` stays a local, workflow-time gate.
- **Release** (`.github/workflows/release-charts.yml`) runs `make chart-deps` before `chart-releaser` so the Bitnami and dex repositories are registered and subchart dependencies resolve, and it passes `skip_existing: true`, so re-runs and already-published versions don't fail the job.
- **Hygiene** applies to both workflows: least-privilege `permissions` (CI: `contents: read`), a `concurrency` group on release so two quick merges can't race, job `timeout-minutes`, and action versions pinned.
- First green release is verified by a human: it will publish `prometheus-pve-exporter-0.1.0` and `outline-1.10.0` (the outline fork has never been released).

Not changing: the CHANGELOG-owns-the-version convention, chart contents, the `Makefile` gate semantics, and the chart-releaser / gh-pages publishing model.

## Capabilities

### New Capabilities
<!-- None. This is CI/release tooling; no spec-level behaviour changes and the repo has no specs. The change sets `skip_specs: true` in `.openspec.yaml`. -->

### Modified Capabilities
<!-- None. -->

## Impact

- `.github/workflows/ci.yml`, `.github/workflows/release-charts.yml`.
- `Makefile` / `docs/dependencies.md` only if CI needs a new tool row (helmfmt is already listed).
- Merging to `main` after this change publishes two charts for the first time (`prometheus-pve-exporter-0.1.0`, `outline-1.10.0`) as GitHub releases and a `gh-pages` index update.
- Known latent issue left in scope for design: `main` is branch-protected, and the release workflow's version-sync step pushes a commit to `main`. It has not fired because the CHANGELOG and `Chart.yaml` versions currently agree.

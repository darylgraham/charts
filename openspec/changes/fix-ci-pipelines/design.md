# Design

## Context

Two workflows exist (see proposal.md for why they fail):

```
ci.yml             pull_request -> main   job `lint-test`: setup-helm -> plugin install -> helm lint -> helm unittest
release-charts.yml push -> main           job `release`:   sync Chart.yaml version from CHANGELOG -> chart-releaser
```

Facts that constrain the approach:

- The `Makefile` is the repo's command surface. Locally `make lint test format` pass; `make chart-deps` (subchart fetch) is run by `test` and `lint`; `make deps` is the tool/login check and is **not** for CI to fetch charts.
- `charts/*/charts/` is gitignored, so `charts/outline` only lints, tests and packages after `helm dependency build`.
- `make validate` needs the `openspec` CLI and fails when no change is active.
- `main` is branch-protected. The action allow list now includes `azure/setup-helm@v4`.
- helmfmt ships pinned release binaries with a checksum file (`digitalstudium/helmfmt` v0.7.0). helm-unittest is v1.2.1 locally.
- Release tags are per chart (`<chart>-<version>`); `home-information` is at 0.1.2, `outline` 1.10.0 and `prometheus-pve-exporter` 0.1.0 have no release.

## Goals / Non-Goals

**Goals:**
- A PR runs the same lint/test/format checks a developer runs locally, and any failure points at one `LABEL_EXIT` line in the log.
- A merge to `main` reaches `chart-releaser` with every chart packageable, and a re-run does not fail on already-published versions.
- Tool versions are pinned, so a new Helm / plugin / action release can't silently break the pipelines.

**Non-Goals:**
- Reworking how versions are derived (the CHANGELOG-owns-the-version convention stays).
- Running `make validate` in CI.
- Migrating to OCI registries, signing charts, or changing the gh-pages publishing model.
- Bumping `chart-releaser-action` to its latest major, or `actions/checkout` past v4.

## Decisions

1. **CI calls `make lint test format`, not `make gates`.** `gates` includes `validate`, which needs `openspec` and fails on an empty `openspec/changes/`, so every PR would go red once active changes are archived. Using `make` targets means local == CI, and each gate prints its own `LABEL_EXIT:<n>`. Alternative: install openspec and loosen `validate` — rejected as extra moving parts for a spec check that is workflow-time, not release-time.
2. **Keep the job id `lint-test` and the workflow name `CI`.** If `main` has a required status check on it, renaming the job would leave the check pending forever. Alternative: rename for clarity — rejected for the same reason.
3. **Tool installation is pinned and explicit.** Helm via `azure/setup-helm@v4` with `version: v3.22.1`; helm-unittest through the Makefile's `helm-unittest` target, which gains a pinned `--version` (`v1.2.1`) so CI and local share one definition; helmfmt by downloading the `v0.7.0` release tarball and verifying it against the published checksums file. Third-party actions are pinned to full commit SHAs with the tag in a comment (a mutable tag in a job with `contents: write` is a supply-chain risk), kept current by Dependabot. Alternatives: `go install` (needs setup-go and an unpinned build), `latest` everywhere (the current failure mode).
4. **Release step runs `make chart-deps` before chart-releaser.** It registers every dependency repository from `Chart.yaml` and runs `helm dependency build`, so the `cr package` step finds its repositories. Alternative: `charts_repos:` on the action — rejected: it duplicates the repo URLs in the workflow and can drift from `Chart.yaml`. The new `make deps` is the tool check and must not be used here.
5. **`skip_existing: true` on chart-releaser.** Re-running a failed release, or a push that changes only docs, must not fail because a version is already published. Alternative: leave off so duplicates fail loudly — rejected: an idempotent release is what a retry needs.
6. **Hygiene.** CI `permissions: contents: read`; release keeps `contents: write` only; release gets `concurrency: { group: release, cancel-in-progress: false }`; CI gets a per-ref concurrency group with `cancel-in-progress: true`; both jobs get `timeout-minutes`. CI also gets `workflow_dispatch` so a failed run can be re-run without a push. No path filters: the repo is small, and filters interact badly with required checks.
7. **The version-sync step is left as is.** It only pushes when a CHANGELOG version differs from `Chart.yaml`, so it is dormant today.

## Risks / Trade-offs

- [First release publishes outline-1.10.0 and prometheus-pve-exporter-0.1.0 publicly] → a human confirms the plan and the result (task requires human verification); `skip_existing` makes a retry safe.
- [The version-sync step pushes to protected `main`; the first time a CHANGELOG version differs from `Chart.yaml` that push is rejected and the release fails] → documented here; fixing it (e.g. a PR check that the two agree, replacing the push) is a follow-up change, not this one.
- [Bitnami's chart repository has been unstable since their 2025 catalog changes; `helm dependency build` could fail on their side] → `chart-deps` fails loudly before `cr`, and the pinned versions in `Chart.lock` bound the exposure. No mitigation beyond that in this change.
- [A required status check on `lint-test` can't be inspected with the current token] → ids kept as-is (decision 2).
- [`azure/setup-helm@v4` is allow-listed by tag; SHA-pinned refs may need new allow-list entries, otherwise CI returns to `startup_failure`] → Product Owner updates the allow list before 5.1 is ticked; stay on v4 (v5 would need it too).

## Migration Plan

1. Build on a `change/fix-ci-pipelines` branch cut from the current branch tip, because `make chart-deps` and the pinned plugin target live there and not on `main`. Open one PR to `main`; the PR run is the first real exercise of `ci.yml`.
2. Merge. The release workflow runs on the merge and is the first exercise of the fixed release job; the Product Owner checks the two new GitHub releases and the `gh-pages` index (`helm repo add` + `helm search repo`).
3. Rollback: revert the workflow commit. Published releases are additive and are not rolled back.

## Open Questions

- Whether `main` requires the `lint-test` status check (needs a repo admin; does not change the approach).

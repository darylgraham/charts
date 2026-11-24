# Design

## Context

See proposal.md for motivation. Facts that constrain the approach (verified by reading the release-please and chart-releaser sources, see the archived spike notes in the devlog once task 1 is done):

- `main` is protected by `protect-main`: no direct pushes (pull-request rule), 0 required approvals, no required status checks, squash or rebase merges. `github-actions` is not a bypass actor.
- Tags and releases created with `GITHUB_TOKEN` do not trigger other workflows, so publishing must happen in the **same workflow run** as release-please, not in a workflow triggered by the release.
- release-please's `helm` strategy updates only `Chart.yaml` `version:` (not `appVersion`) and prepends to the chart's `CHANGELOG.md` (created if missing).
- chart-releaser `upload --skip-existing` skips when a release exists and does **not** attach the package; `--replace-existing` attaches the package to an existing release. Its index points at the release asset URL.
- release-please's `prerelease` versioning: with `prerelease-type` set and a non-prerelease version it appends the type verbatim (`1.3.0-rc`), then bumps a trailing number (`rc.1`); with `prerelease: false` it strips the suffix on the next release (graduation). `rc.0` as the type is expected to give `1.3.0-rc.0` first; unconfirmed until the spike.
- Existing tags are `<chart>-<version>` (`home-information-0.1.2`, `outline-1.10.0`, `prometheus-pve-exporter-0.1.0`).

## Goals / Non-Goals

**Goals:**
- Versions are decided by the pipeline from commit types, never typed by an author, and are visible in git (`Chart.yaml`).
- Every release is gated by a reviewable release PR; no direct pushes to `main`.
- Release candidates are available through the same flow.

**Non-Goals:**
- Automatic `appVersion` bumps, chart signing, OCI publishing, a custom semver implementation.
- Changing the gh-pages publishing model (index and release assets stay as they are).
- Rewriting existing CHANGELOG history.

## Decisions

1. **release-please in manifest mode, `helm` release type, per-chart packages.** Off-the-shelf, works with a protected `main` (it uses PRs), and keeps versions committed. Alternative: compute the version in the release job without committing (custom bash semver, `Chart.yaml` never shows the real version, no human gate) — rejected.
2. **Tag format `<chart>-<version>`:** `include-component-in-tag: true`, `include-v-in-tag: false`, `tag-separator: "-"`, so it matches existing tags and chart-releaser's default release name. `.release-please-manifest.json` is seeded with the current versions (0.1.2, 1.10.0, 0.1.0) so no historical release is re-proposed.
3. **release-please owns the tag and GitHub release; chart-releaser only publishes.** The publish job runs `cr package`/`cr upload --replace-existing`/`cr index` for the released paths only (from release-please's `paths_released` output), not chart-releaser's "changed since last tag" detection. Alternative: let chart-releaser create the release — rejected because release-please cannot reliably skip its own release and still find the last version. The exact invocation (whether through `chart-releaser-action` with `install_only` and a `cr` config file, or a direct `cr` download) is fixed by the spike (task 1.4); the fallback is `gh release upload` for the asset plus `cr index`.
4. **One workflow, two jobs** (`release-please`, then `publish` with `needs` and `if: releases_created`). Needed because `GITHUB_TOKEN`-created releases do not trigger other workflows. Keep the `release` concurrency group (`cancel-in-progress: false`).
5. **Bump policy:** `bump-minor-pre-major: true` (breaking changes in 0.x bump the minor) and `bump-patch-for-minor-pre-major: true` (`feat` in 0.x bumps the patch), per package for the 0.x charts; `outline` (>= 1.0) uses plain semver. Plain `fix`/`feat`/`perf`/`feat!` mapping otherwise. Alternative: major bump for breaking pre-1.0 — rejected by the Product Owner (usual convention).
6. **Release candidates via release-please's `prerelease` versioning,** opted in per chart by config (`"versioning": "prerelease"`, `"prerelease": true`, `"prerelease-type": "rc.0"`), entered and left through normal PRs. The default config uses plain `default` versioning. Alternatives: an rc on every merge to `main` (needs our own version/counter logic, races with the release PR) and on-demand rc from a PR branch (publishes unreviewed code with a write token to the shared index) — both rejected.
7. **PR-title check** with `amannn/action-semantic-pull-request`, pinned to a SHA, on the `pull_request` event (not `pull_request_target`) since it only reads the title from the event payload. Allowed types: `feat fix docs style refactor perf test build ci chore revert`. Dependabot gets `commit-message: { prefix: ci }`.
8. **All new third-party actions are pinned to full commit SHAs** (repo policy), resolved at apply time (release-please-action is currently v5.x; the exact SHA and whether v4 or v5 is used is decided then, not here).
9. **CHANGELOG adoption:** keep each chart's existing history; remove the stale `## [Unreleased]` heading so generated entries sit directly under the title. `outline` gains a generated CHANGELOG on its first release.

## Risks / Trade-offs

- [A merged PR with a non-conventional title silently produces no release] → the PR-title check; recommend restricting allowed merge methods to squash (a rebase merge would bypass the title check by landing individual commits).
- [GitHub Actions cannot trigger CI on the release PR (created with `GITHUB_TOKEN`)] → it only changes `Chart.yaml` and `CHANGELOG.md`, and no check is required; accepted. A PAT or GitHub App would be the later fix.
- [The changelog interaction with the existing Keep-a-Changelog files, the `rc.0` format and `--replace-existing` through chart-releaser are unverified] → task 1 is a spike that settles them before any workflow is rewritten; if a result contradicts a decision here, update this file first.
- [While a chart is in the rc channel it cannot ship a stable hotfix until it is graduated] → documented; graduate (or leave the channel) with a one-line config PR.
- [The first release after cut-over publishes a real version] → verified in the final section with the Product Owner's confirmation.
- [release-please marks "pre-major" versions with its own logic; a version mismatch from `Chart.yaml`] → manifest seeded with current versions and verified by a dry run before the workflow is switched.

## Migration Plan

1. Spike on a throwaway branch (nothing merged).
2. Land config + CHANGELOG normalisation, then the new workflow and PR-title check in the same PR; the PR itself is titled `ci: ...` so it triggers no release.
3. The Product Owner restricts merge methods to squash.
4. Verify end to end with a real `fix(<chart>)` PR (a release PR appears, merge it, release + index verified). Rollback: revert the workflow commit; published releases are additive.

## Open Questions

- Which real chart fix to use for the end-to-end verification (Product Owner's choice; does not change the approach).

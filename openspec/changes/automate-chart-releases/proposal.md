# Proposal

## Why

Chart versions are set by hand: authors must edit `CHANGELOG.md`, and the release workflow rewrites `Chart.yaml` and **pushes a commit to `main`**. `main` is governed by the `protect-main` ruleset, whose pull-request rule blocks direct pushes by `github-actions`, so that step fails the first time a CHANGELOG version differs from `Chart.yaml` (see the archived `fix-ci-pipelines` design). The Product Owner wants the pipeline, not the author, to decide the version, using semantic versioning, and to be able to publish release candidates (`-rc.N`).

## What Changes

- **Adopt release-please** (manifest mode, one package per chart, `helm` release type). On every push to `main` it reads the Conventional Commits since each chart's last tag, scoped to `charts/<name>/`, and opens or updates a **release PR** that bumps `Chart.yaml` `version:` and the chart `CHANGELOG.md`. Merging that PR is the human gate: it creates the tag (`<chart>-<version>`, matching the existing tags) and the GitHub release.
- **Bump rules (semver):** `feat` -> minor, `fix`/`perf` -> patch, `!` or a `BREAKING CHANGE:` footer -> major; for charts below 1.0.0 breaking changes bump the minor and `feat` bumps the patch. `docs`, `chore`, `ci`, `test`, `style` and `build` do not release. `outline` (1.10.0) is included.
- **Publishing moves into the same workflow:** a second job runs only for the charts release-please just released, packages them, attaches the `.tgz` to the release-please release, and updates the `gh-pages` Helm index with chart-releaser. The old "sync version from CHANGELOG and push" step and chart-releaser's own change detection are removed.
- **Release candidates:** a chart opts into a pre-release channel by setting `prerelease: true` and `prerelease-type: rc.0` for its package in the release-please config (a normal PR). Releases then go `1.3.0-rc.0`, `1.3.0-rc.1`, ... and are marked as GitHub pre-releases (Helm hides them unless `--devel`). Setting `prerelease` back to `false` graduates to `1.3.0`.
- **PR-title check:** squash merges make the PR title the commit message, so a CI check enforces a Conventional Commit title. Dependabot is configured to use a `ci` commit prefix so its PRs pass.
- **Docs:** replace the "CHANGELOG owns the version" convention in `CLAUDE.md`, document how to mark a breaking change and how to enter and leave the rc channel.
- Authors stop editing `version:` and `[Unreleased]` sections; existing CHANGELOG history is kept.

**BREAKING (process):** the hand-maintained `## [Unreleased]` convention and "never hand-edit `version:`" rule are retired. Releases now happen only by merging a release PR.

## Capabilities

### New Capabilities
<!-- None. CI/release tooling; no spec-level behaviour. The change sets `skip_specs: true` in `.openspec.yaml`. -->

### Modified Capabilities
<!-- None. -->

## Impact

- `.github/workflows/release-charts.yml` (rewritten), new `.github/workflows/pr-title.yml`, `.github/dependabot.yml`.
- New `release-please-config.json` and `.release-please-manifest.json` at the repo root.
- `charts/*/CHANGELOG.md` (normalised; `outline` gains one), `CLAUDE.md`, root `README.md`.
- Repo settings (Product Owner): "Allow GitHub Actions to create and approve pull requests" is already enabled; restricting the ruleset's allowed merge methods to squash is recommended.
- The first real release through the new flow publishes a patch or minor of a chart chosen by the Product Owner.

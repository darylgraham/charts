# Tasks

## 1. Spike: settle the unverified details

Nothing from this section is merged; use a throwaway branch (`spike/release-please`) and delete it afterwards. Record findings in a devlog note; if a result contradicts `design.md`, amend `design.md` first.

- [ ] 1.1 On the throwaway branch add a draft `release-please-config.json` and `.release-please-manifest.json` (current versions) and run release-please in dry-run against it (`release-please release-pr --dry-run`, token from `gh auth token`; the Product Owner approves running the package). Verify with synthetic conventional commits that the proposed versions are: `feat` on a 0.x chart -> patch, `feat!` on a 0.x chart -> minor, `fix` -> patch, `feat` on `outline` (1.10.0) -> minor, `docs` -> no release
- [ ] 1.2 In the same dry-run set `prerelease: true` and `prerelease-type: rc.0` on one chart and verify the first version is `X.Y.Z-rc.0` then `-rc.1`, and that flipping `prerelease` to `false` yields the plain `X.Y.Z`
- [ ] 1.3 Verify where the generated entry lands in the existing Keep-a-Changelog `CHANGELOG.md` (stale `## [Unreleased]`?) and that `outline` gets a new file; record the exact normalisation needed
- [ ] 1.4 Verify the publish mechanism against a throwaway release (`spike-<ts>` tag created and deleted by hand, Product Owner approves): `cr package` + `cr upload --replace-existing` attaches the `.tgz` to an existing release, and `cr index` can write the index entry (use a scratch pages branch or `--skip-upload`/dry flags, not the live `gh-pages`). Record the exact working command line, or switch to the `gh release upload` fallback in `design.md`

## 2. release-please config and CHANGELOG adoption

- [ ] 2.1 Add `release-please-config.json` (three packages, `helm` type, tag settings from design decisions 2 and 5, no prerelease) and `.release-please-manifest.json` seeded with 0.1.2, 1.10.0, 0.1.0, as confirmed by 1.1; verify both parse as JSON and a dry-run proposes no release for the current tree
- [ ] 2.2 Normalise `charts/home-information/CHANGELOG.md` and `charts/prometheus-pve-exporter/CHANGELOG.md` as found in 1.3 (remove the stale `## [Unreleased]` heading; keep all history); verify `git diff` shows only that removal and that the dry-run still proposes no release

## 3. Release workflow

- [ ] 3.1 Rewrite `.github/workflows/release-charts.yml`: job `release-please` (SHA-pinned action, outputs `releases_created`, `paths_released`, permissions `contents: write`, `pull-requests: write`) and job `publish` (`needs`, `if: releases_created`, `contents: write`) that sets up the pinned Helm, runs `make chart-deps`, then packages, uploads and indexes only the released charts using the command line proven in 1.4; remove the CHANGELOG-sync step; keep the `release` concurrency group and timeouts. Verify the file parses, every `uses:` is a 40-char SHA with a tag comment, and the old sync/push step is gone (`grep -n 'git push' .github/workflows/release-charts.yml` is empty)

## 4. Conventional-title enforcement

- [ ] 4.1 Add `.github/workflows/pr-title.yml` (`pull_request` events `opened edited synchronize reopened`, `permissions: pull-requests: read`, SHA-pinned `amannn/action-semantic-pull-request`, allowed types from design decision 7); verify the file parses and the PR for this change passes it
- [ ] 4.2 Set `commit-message: { prefix: ci }` for the `github-actions` ecosystem in `.github/dependabot.yml` and verify it parses and the prefix key is present

## 5. Documentation

- [ ] 5.1 Update `CLAUDE.md`: replace the "CHANGELOG owns the version" decision with the release-please flow (never hand-edit `version:` or CHANGELOGs; release by merging the release PR), record the squash-merge and PR-title rule, how to mark a breaking change (`feat!:` / `BREAKING CHANGE:`, including values renames and selector changes), and the rc channel procedure; verify `grep -n 'Unreleased' CLAUDE.md` finds no remaining instruction to edit `[Unreleased]`
- [ ] 5.2 Add a short "Releasing" section to the root `README.md` (commit types -> bump, release PR, rc channel, `helm search repo --devel`) and verify the documented commands are correct against the spike notes

## 6. Prove it on GitHub

- [ ] 6.1 **Needs human confirmation.** Product Owner restricts the `protect-main` ruleset's allowed merge methods to squash only (Settings -> Rules); verify with `gh api repos/darylgraham/charts/rulesets/17866777 --jq '.rules[]|select(.type=="pull_request").parameters.allowed_merge_methods'` returning only `squash`
- [ ] 6.2 Open the PR for this change (title `ci: automate chart releases with release-please`), verify `CI` and `PR title` are green, merge it after the Product Owner's confirmation, then verify the `Release Charts` run on `main` succeeds, creates no release (a `ci:` change), and that no release PR is opened
- [ ] 6.3 **Needs human confirmation.** With a real `fix(<chart>): ...` PR chosen by the Product Owner, verify the release PR appears with the expected patch version and a generated CHANGELOG entry; after the Product Owner merges the release PR verify the tag, the GitHub release with its `.tgz` asset, the `gh-pages` index (`helm repo update && helm search repo darylgraham`) and a re-run of the workflow succeeding without changes
- [ ] 6.4 Verify a bad PR title is rejected (open a draft PR titled `update stuff`, confirm `PR title` fails, then close it)

## Workflow follow-up

- Archive the change once 6.1-6.4 are confirmed.
- A real release candidate is not published as part of this change; the first use of the rc channel follows the documented procedure.

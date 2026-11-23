# Tasks

## 1. Pinned tooling in the Makefile

- [x] 1.1 Pin the helm-unittest plugin in the `helm-unittest` target (`--version v1.2.1`) and verify `make init` on a machine without the plugin installs 1.2.1 (`helm plugin list`) and `make deps` reports `DEPS_EXIT:0`
- [x] 1.2 Record the pinned CI tool versions (Helm v3.22.1, helm-unittest v1.2.1, helmfmt v0.7.0) in `docs/dependencies.md` and verify each row still matches its `make deps` check

## 2. PR CI runs the repo's gates

- [x] 2.1 Rewrite `.github/workflows/ci.yml`: keep workflow name `CI` and job id `lint-test`; add `workflow_dispatch`, `permissions: contents: read`, a per-ref concurrency group with `cancel-in-progress: true`, `timeout-minutes`; install Helm (`azure/setup-helm@v4`, pinned version), the plugin via `make init`, and helmfmt from the pinned release tarball with checksum verification; run `make lint`, `make test`, `make format` as separate steps. Verify the file parses (`python3 -c 'import yaml,sys; yaml.safe_load(open(".github/workflows/ci.yml"))'`) and that every gate step is a bare `make <target>` call
- [x] 2.2 Run the three CI gate commands locally from a clean checkout of the branch (`git clone` into a scratch dir, no `charts/*/charts/`) and verify `LINT_EXIT:0`, `TEST_EXIT:0`, `FORMAT_EXIT:0` — proving `chart-deps` makes outline lintable without pre-fetched subcharts

## 3. Release job packages every chart

- [x] 3.1 Update `.github/workflows/release-charts.yml`: add `make chart-deps` (with Helm set up first, via the same pinned `azure/setup-helm@v4`) before chart-releaser, `skip_existing: true`, a `concurrency` group `release` with `cancel-in-progress: false`, and `timeout-minutes`; leave the version-sync step unchanged. Verify the file parses and that `make chart-deps` is ordered before the `helm/chart-releaser-action` step
- [x] 3.2 Reproduce the failing packaging step locally in a scratch clone with no `~/.config/helm` repositories: run `make chart-deps` then `helm package charts/outline -d <scratch>` and verify a `.tgz` is produced (the original failure was `no repository definition for https://charts.bitnami.com/bitnami`)

## 4. Prove it on GitHub

- [ ] 4.1 Open the PR from `change/fix-ci-pipelines` to `main` and verify the `CI` run starts a job (not `startup_failure`) and completes green: `gh run list --workflow ci.yml --limit 1` shows `completed success`, and the job log shows `LINT_EXIT:0`, `TEST_EXIT:0`, `FORMAT_EXIT:0`
- [ ] 4.2 **Needs human confirmation.** Before merging, confirm the Product Owner is happy for the merge to publish `prometheus-pve-exporter-0.1.0` and `outline-1.10.0` as GitHub releases. After the merge, verify `gh run list --workflow release-charts.yml --limit 1` shows `completed success`, `gh release list` shows both new releases, and `helm repo add darylgraham https://darylgraham.github.io/charts && helm search repo darylgraham` lists all three charts. Do not tick until the Product Owner confirms
- [ ] 4.3 Re-run the release workflow (`gh workflow run release-charts.yml`) and verify it also completes green (idempotent via `skip_existing`)

## Workflow follow-up

- Archive the change once 4.2 and 4.3 are confirmed.
- Follow-up change (not this one): replace the release workflow's version-sync push to protected `main` with a PR-time check that each chart's `Chart.yaml` version matches its CHANGELOG.

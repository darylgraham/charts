# DEVLOG: add-prometheus-pve-exporter-chart

New Helm chart `charts/prometheus-pve-exporter` deploying prometheus-pve-exporter v3.11.0, with credential handling and an optional ServiceMonitor.

## 1. Chart skeleton and core workload

- **[architect]** Base: `90239e9` — chart skeleton, Deployment/Service/ServiceAccount, hardened defaults, probes, NOTES.
- **[architect]** Block 1.1–1.3: create `charts/prometheus-pve-exporter/` following `charts/home-information` conventions (`_helpers.tpl` with `prometheus-pve-exporter.{name,fullname,chart,labels,selectorLabels,serviceAccountName}`, `templates/tests/*_test.yaml`).
  - Chart.yaml: `type: application`, `version: 0.1.0`, `appVersion: "3.11.0"`. CHANGELOG.md: `[Unreleased]` + `## [0.1.0] - 2026-11-02` (keep-a-changelog; do not hand-bump version later).
  - Image `prompve/prometheus-pve-exporter`, tag defaults to `appVersion` (NO `v` prefix). Container port 9221 named `http`; Service ClusterIP 9221.
  - values: replicaCount 1, image, imagePullSecrets, nameOverride/fullnameOverride, serviceAccount, podAnnotations/podLabels, podSecurityContext (`runAsNonRoot`, `runAsUser/Group/fsGroup` 101, seccomp RuntimeDefault), securityContext (drop ALL, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`), service, resources, extraArgs (list, appended to container `args`), liveness/readiness probes, nodeSelector/tolerations/affinity. Comment every key (README will document them later).
  - Probes: HTTP GET `/` on `http`. Design decision 8: this is UNVERIFIED. If you can't confirm that the exporter serves 200 on `/` (no image/network available is likely), use it as default and say so explicitly in your report so I can decide; do not switch to tcpSocket on your own.
  - Do NOT add credentials/secret/env wiring, ServiceMonitor, README or examples — later blocks. The Deployment must still render with no credentials for now (credential validation arrives in 2.1).
  - Tests (helm-unittest, `templates/tests/`): assert image tag default and override, port 9221, Service port, securityContext values, probes, extraArgs → args, name overrides. Assert specific values, not just rendering.
  - Binding: design.md decisions 1, 7, 8, 11; specs `pve-exporter-deployment` requirements "Exporter workload", "Hardened and standard pod settings", "Health probes".
  - Gates: `make lint`, `make test`; `helmfmt --check` via `make format` will also scan other charts — only report on `charts/prometheus-pve-exporter` findings.

- **[worker]** Block 1.1-1.3 done. Created `charts/prometheus-pve-exporter/` (Chart.yaml 0.1.0/appVersion 3.11.0, CHANGELOG, .helmignore, _helpers.tpl, values.yaml, deployment/service/serviceaccount, NOTES.txt) and suites `templates/tests/deployment_test.yaml`, `service_test.yaml` (assert image tag default/override, port 9221, securityContext, probes, extraArgs, name overrides, SA, scheduling).
  - Probe path `/` is UNVERIFIED (design decision 8): no image/network access. Kept httpGet `/` on `http` as default; did not switch to tcpSocket. Architect to decide.
  - NOTES.txt prints service DNS, port-forward, `/pve?target=...` and `/metrics` curl examples; no credentials.
  - helmfmt style: `_helpers.tpl` and `deployment.yaml` were reformatted to helmfmt output (flush-left `{{- with }}` in deployment.yaml) so the chart passes `helmfmt --check`; `make format` reports no pve-exporter files.
  - Gates: `TEST_EXIT:0` (65 tests, all suites pass). `LINT_EXIT:1` is baseline: only `charts/outline` fails (missing subchart deps / nil pointer in secret_redis_credentials.yaml); prometheus-pve-exporter lints clean (only INFO: icon recommended). `FORMAT_EXIT:1` is baseline (home-information, outline); none for pve-exporter. Ran `make init` to install the missing helm-unittest plugin.
  - Not touched: tasks.md, Makefile, Chart.yaml version.
  - → @reviewer

- **[reviewer]** Block 1.1-1.3: **Approve with nits.**
  - Gates re-run via make: `TEST_EXIT:0` (65 tests, 4 suites). `LINT_EXIT:1` and `FORMAT_EXIT:1` are baseline only (outline lint error at secret_redis_credentials.yaml:12; format hits home-information/outline); pve-exporter lints clean (INFO icon only) and `make format` mentions no pve-exporter file. Makefile untouched.
  - `helm template` (defaults and with extraArgs/podAnnotations/podLabels) renders valid output: image `prompve/prometheus-pve-exporter:3.11.0` (no `v`), port 9221 `http`, ClusterIP Service targeting `http`, selector labels match between Deployment and Service, hardened pod/container contexts present, probes on `http`. `_helpers.tpl` and `deployment.yaml` after the helmfmt rewrite are sound: `{{- with }}` blocks and nindent widths are correct, no stray whitespace in output.
  - Decisions: 1 (name/0.1.0/appVersion 3.11.0), 7 (hardening values exactly as specified, asserted by tests), 8 (probes httpGet `/` on `http`; unverified status disclosed in worker report), 11 (CHANGELOG has Unreleased + 0.1.0; Chart.yaml version only the initial value) all comply. Scope clean: no credentials/Secret/env, ServiceMonitor, README or examples. NOTES.txt contains no credentials and the render contains no password/token strings.
  - Tests assert specific values (image tag default/override, port, both securityContexts, probes, args absent/present, name/selector overrides, SA name/automount/disabled); no loosened assertions.
  - Nits (non-blocking): (1) Chart.yaml has no `icon` (lint INFO) - optional. (2) `deployment.yaml` omits a pod checksum annotation; fine now, revisit when the Secret arrives in 2.x. (3) `serviceAccount.automount: false` default differs from home-information; reasonable for this app, just keep it documented in the README block. (4) Test file naming `*_test.yaml` differs from home-information's `secret_test.yaml` style only trivially; consistent.
  - Architectural note: probe path `/` still needs the Architect's/PO's decision or a real-image check (design decision 8); note the tcpSocket fallback lives in values only, so switching is a values+test change.
  - Needs human confirmation later: read-only root FS with uid 101 on a real cluster (design risk 1); not part of this block.

- **[architect]** Gates for 1.1–1.3: `TEST_EXIT:0` (65 tests), `VALIDATE_EXIT:0`, `LINT_EXIT:1`, `FORMAT_EXIT:1`. Both failures are baseline on `charts/outline` (missing subchart deps, nil pointer in `secret_redis_credentials.yaml:12`) and `home-information` (format). `helm lint charts/prometheus-pve-exporter` is clean (INFO: icon) and `helmfmt --check charts/prometheus-pve-exporter` reports all 6 files formatted. Task 1.1 says "verify `make lint` reports `LINT_EXIT:0`", which cannot be met while `outline` is broken. STOPPED before ticking/committing; ❓ @product-owner — see report.

- **[architect]** Resolved the `LINT_EXIT:1` stop at the Product Owner's direction. Root cause was not an `outline` template bug: its subchart dependencies (postgresql/redis/minio/dex) were never fetched, so `.Values.redis.master.service.ports` was absent. Added a `deps` Makefile target (adds repos from `Chart.yaml`, runs `helm dependency build`) that `lint` and `test` depend on, and gitignored `charts/*/charts/`. Now `LINT_EXIT:0`, `TEST_EXIT:0`, `VALIDATE_EXIT:0`. `FORMAT_EXIT:1` remains: baseline on `home-information`/`outline` only, out of scope per task 4.3; `helmfmt --check charts/prometheus-pve-exporter` is clean. Note: CI (`.github/workflows/ci.yml`) runs `helm lint charts/*` directly and does not fetch deps, so it likely still fails on `outline` — out of scope here, flagged to the Product Owner. Reviewer nits (icon, checksum annotation in 2.x, `automount: false` to document in README) parked in NEXT.

## NEXT

- **Up next:** section 1 supervisor review (base `90239e9`).
- **Parked nits:** add chart `icon`; add Secret checksum annotation when the Secret lands (2.1); document `serviceAccount.automount: false` in README (4.1).
- **Open questions:** probe path `/` unverified (design decision 8).
- **Nits / deferred:** none.
- **Carry-forward:** `make format` already fails on `home-information` and `outline` (baseline debt, out of scope). `make gates` also reports `VALIDATE` only once a change exists — it does now.

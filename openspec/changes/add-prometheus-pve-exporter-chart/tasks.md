# Tasks

## 1. Chart skeleton and core workload

- [x] 1.1 Create `charts/prometheus-pve-exporter/` with `Chart.yaml` (v0.1.0, appVersion 3.11.0), `.helmignore`, `_helpers.tpl`, `values.yaml`, and `CHANGELOG.md` (`[Unreleased]` + `[0.1.0]`); verify `make lint` reports `LINT_EXIT:0`
- [x] 1.2 Add `deployment.yaml`, `service.yaml`, `serviceaccount.yaml` (port 9221, extraArgs, resources, scheduling, hardened securityContext per design decision 7, probes per decision 8); confirm the probe path against the image or fall back to tcpSocket, and verify with a helm-unittest suite asserting image tag, port, securityContext and probes (`TEST_EXIT:0`)
- [x] 1.3 Add `templates/NOTES.txt` describing how to reach `/pve` and `/metrics`; verify `helm template` renders without error

## 2. Credentials and configuration

- [ ] 2.1 Add `secret.yaml` and env wiring for password and token auth with `PVE_VERIFY_SSL`, plus render-time `fail` validation (no credentials, password+token, env+file); verify with helm-unittest cases for each scenario in `pve-exporter-deployment` (`TEST_EXIT:0`)
- [ ] 2.2 Add existing-Secret support with configurable key names; verify no Secret is rendered and env refs use the configured keys
- [ ] 2.3 Add mounted `pve.yml` mode (inline or existing Secret) mounted at `/etc/prometheus/pve.yml` with no `PVE_*` credential vars, plus optional CA Secret mount; verify with unit tests, including that no credential value appears outside Secret objects
- [ ] 2.4 Add `examples/` values files (password, token, existing-secret, pve.yml multi-module); verify each renders via `helm template -f` in a unit test or `make lint`

## 3. Prometheus integration

- [ ] 3.1 Add `servicemonitor.yaml` (off by default; targets, params, relabeling to `instance`, labels, interval, scrapeTimeout, namespace); verify helm-unittest cases for default-off, enabled, multiple targets, parameter overrides, and label passthrough (`TEST_EXIT:0`)

## 4. Documentation, repo registration, and release

- [ ] 4.1 Write the chart `README.md`: values table, auth modes, Proxmox `PVEAuditor` role setup, TLS/CA limits, ServiceMonitor, and a plain-Prometheus `scrape_configs` example with `__param_target` relabeling; verify the example matches the monitoring spec scenario and every `values.yaml` key is documented
- [ ] 4.2 Add the chart to the root `README.md` table; verify the row links to the chart README
- [ ] 4.3 Run `make gates` and fix findings within this chart (format failures on the other charts predate this change and are out of scope); verify `LINT_EXIT:0`, `TEST_EXIT:0`, `FORMAT_EXIT` for `charts/prometheus-pve-exporter` alone via `helmfmt --check charts/prometheus-pve-exporter` printing no unformatted files, and `VALIDATE_EXIT:0`
- [ ] 4.4 Human verification: install on a real cluster against a Proxmox VE host, confirm the pod starts under the read-only root filesystem and reaches Ready with no liveness restarts (proving the `/` probe path returns 2xx; if not, switch probes to `tcpSocket`), confirm it also starts with `extraArgs: [--no-collector.config]`, and `curl 'http://<svc>:9221/pve?target=<host>&module=default&cluster=1&node=1'` returns metrics; wait for Product Owner confirmation before ticking

## Workflow follow-up

- Archive the change after the Product Owner confirms task 4.4.

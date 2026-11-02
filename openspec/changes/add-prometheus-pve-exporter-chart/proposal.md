# Proposal

## Why

There is no Helm chart in this repo for monitoring Proxmox VE. The
[prometheus-pve-exporter](https://github.com/prometheus-pve/prometheus-pve-exporter) exposes Proxmox VE
metrics to Prometheus, and running it in-cluster against one or more PVE hosts needs a deployment,
credential handling, and scrape wiring that every user would otherwise hand-write.

## What Changes

- Add a new chart `charts/prometheus-pve-exporter` that deploys the exporter (`prompve/prometheus-pve-exporter`) as a single Deployment with a Service on port 9221.
- Support Proxmox credentials from either a chart-created Secret (password or API-token auth) or an existing Secret, delivered to the exporter without being written to a ConfigMap.
- Support an optional mounted `pve.yml` for multi-module setups, and passing exporter flags (e.g. collector toggles, `--no-collector.config`).
- Provide an optional Prometheus Operator `ServiceMonitor` supporting the multi-target `/pve?target=` pattern, plus documented plain-Prometheus scrape config.
- Add helm-unittest suites, README, CHANGELOG, example values, and register the chart in the root README.

No existing chart changes. No **BREAKING** changes.

## Capabilities

### New Capabilities
- `pve-exporter-deployment`: Running the exporter in a cluster — image, listen port, credential sourcing (password, token, existing Secret, mounted config), TLS verification setting, probes, and standard chart knobs (resources, security context, scheduling).
- `pve-exporter-monitoring`: How Prometheus discovers and scrapes the exporter — optional ServiceMonitor, per-target scrape parameters (`module`, `cluster`, `node`), and documented scrape configuration.

### Modified Capabilities

None.

## Impact

- New directory `charts/prometheus-pve-exporter/` (templates, values, tests, README, CHANGELOG, examples).
- Root `README.md` chart table gains a row.
- CI (`make lint` / `make test`) picks the chart up automatically via `charts/*`; the release workflow picks it up via its CHANGELOG-driven version sync.
- External dependency: Docker Hub image `prompve/prometheus-pve-exporter` (multi-arch, tags without `v` prefix). Optional dependency on Prometheus Operator CRDs when the ServiceMonitor is enabled.

# Changelog

All notable changes to the prometheus-pve-exporter Helm chart are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-11-02
### Added
- Initial release: Deployment, Service and ServiceAccount for prometheus-pve-exporter v3.11.0 with hardened defaults and HTTP probes
- Credentials from a chart-managed or existing Secret as `PVE_*` environment variables (password or API token), with `pve.verifySsl` and render-time validation
- Mounted `pve.yml` mode (`config.pveYml` or `config.existingSecret`) with no `PVE_*` variables, an optional CA Secret mount (`tls.caSecret`) and a writable `/tmp` emptyDir; in env mode the CA mount also sets `REQUESTS_CA_BUNDLE` to `<tls.caMountPath>/<tls.caKey>`, and config mode rejects `pve.verifySsl: false` and `pve.tokenNameKey`/`pve.tokenValueKey`
- Example values files in `examples/` (password, token, existing Secret, multi-module `pve.yml` with a custom CA, ServiceMonitor with two targets)
- Optional Prometheus Operator `ServiceMonitor` (`serviceMonitor.*`) scraping `/pve`, with `module`/`cluster`/`node` parameters, multi-target endpoints that set the `instance` label, per-target `module`/`cluster`/`node` overrides, `relabelings` and `metricRelabelings`, and custom labels, annotations, interval, scrape timeout and namespace; empty targets are rejected
- Chart README covering install, authentication modes, Proxmox VE `PVEAuditor` setup, TLS/CA, ServiceMonitor, a plain-Prometheus `scrape_configs` example and the full values table

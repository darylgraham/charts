# Changelog

All notable changes to the prometheus-pve-exporter Helm chart are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-11-02
### Added
- Initial release: Deployment, Service and ServiceAccount for prometheus-pve-exporter v3.11.0 with hardened defaults and HTTP probes
- Credentials from a chart-managed or existing Secret as `PVE_*` environment variables (password or API token), with `pve.verifySsl` and render-time validation
- Mounted `pve.yml` mode (`config.pveYml` or `config.existingSecret`) with no `PVE_*` variables, an optional CA Secret mount (`tls.caSecret`) and a writable `/tmp` emptyDir
- Example values files in `examples/` (password, token, existing Secret, multi-module `pve.yml` with a custom CA)

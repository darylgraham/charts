# Design

## Context

New chart in a repo whose existing charts (`home-information`, forked `outline`) set the conventions: `_helpers.tpl` with `<chart>.fullname/labels/selectorLabels`, helm-unittest suites in `templates/tests/`, a keep-a-changelog `CHANGELOG.md` whose top version the release workflow copies into `Chart.yaml`, and `examples/` values files. See proposal.md for motivation.

Facts about the exporter (from its README and Dockerfile, v3.11.0): listens on `[::]:9221`; image `prompve/prometheus-pve-exporter` on Docker Hub, tags without a `v` prefix, runs as uid 101, entrypoint `/opt/prometheus-pve-exporter/bin/pve_exporter`; default config path `/etc/prometheus/pve.yml`; if `PVE_USER` (or `PVE_USER_FILE`) is set, configuration comes from `PVE_USER`, `PVE_PASSWORD`, `PVE_TOKEN_NAME`, `PVE_TOKEN_VALUE`, `PVE_VERIFY_SSL`, `PVE_MODULE` instead of the file; scrape endpoint `/pve?target=&module=&cluster=&node=`; self-metrics on `/metrics`. Defaults for `cluster`/`node` params are not documented, so the chart always sends them explicitly.

## Goals / Non-Goals

**Goals:**
- Working install with only a user and password/token supplied.
- Secure by default (no plaintext secrets outside a Secret, hardened container).
- First-class multi-target scraping through a ServiceMonitor.

**Non-Goals:**
- Ingress / HTTPRoute: the exporter is a cluster-internal scrape target and exposes credentials-backed access to Proxmox.
- Managing Proxmox users/roles (documented only: `PVEAuditor` at `/`).
- Prometheus Operator `Probe`/`PodMonitor`, alert rules, Grafana dashboards, NetworkPolicy, HPA/PDB (single replica; deferred).

## Decisions

1. **Chart name and layout:** `charts/prometheus-pve-exporter`, `type: application`, initial `version: 0.1.0`, `appVersion: "3.11.0"`. Alternative: shorter `pve-exporter` — rejected to match the upstream name and search terms.
2. **Credentials via `PVE_*` env vars from a Secret** (default mode), not a generated `pve.yml`. Alternative: always mount `pve.yml` — rejected because env mode needs no volume and works with a read-only root filesystem. Environment `valueFrom.secretKeyRef` is used for each variable; no value is ever rendered into a ConfigMap, args, or NOTES.
3. **Existing-Secret support** mirrors `home-information`: `pve.existingSecret` plus per-key name overrides (`userKey`, `passwordKey`, `tokenNameKey`, `tokenValueKey`); when set, no Secret is created. Password vs token mode is chosen by which of `password` / `tokenName` is set (or which key names are configured); setting both is a render-time `fail`.
4. **Mounted `pve.yml` mode** (`config.pveYml` inline, or `config.existingSecret`) for multiple modules/Proxmox clusters, stored in a Secret (it contains credentials) and mounted read-only at `/etc/prometheus/pve.yml`. In this mode no `PVE_*` credential vars are emitted, because the exporter treats `PVE_USER` as "use env, ignore file".
5. **Validation with `required`/`fail`** at render time for: no credentials source at all; both password and token; both file and env modes configured. Alternative: let the pod crash-loop — rejected, worse UX.
6. **TLS:** `pve.verifySsl` (default `true`) sets `PVE_VERIFY_SSL`; `tls.caSecret`/`tls.caKey` optionally mounts a CA bundle. In env mode the exporter can't point `verify_ssl` at a path, so a custom CA is supported only in `pve.yml` mode (`verify_ssl: /path`); the README documents this limit.
7. **Hardening defaults:** `runAsNonRoot: true`, `runAsUser: 101`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, drop ALL, `seccompProfile: RuntimeDefault`. Image runs as uid 101 so this is compatible; validated by a unit test on rendered securityContext, and called out as needing cluster confirmation (read-only FS with Python).
8. **Probes:** HTTP GET `/` on the named `http` port for liveness and readiness. The exporter is believed to serve an index page there; this is unverified, so the first section confirms it against the image and falls back to `tcpSocket` if `/` isn't a 200.
9. **ServiceMonitor** (`monitoring.coreos.com/v1`) is off by default and gated only on `serviceMonitor.enabled` (not on `.Capabilities`, which would break `helm template`). Each entry in `serviceMonitor.targets` becomes one endpoint with `path: /pve`, params `module`, `cluster`, `node`, `target`, and a relabeling that sets `instance` to the target. With no targets configured it renders a single endpoint without a `target` param (exporter running on the PVE host). Alternative: the Prometheus `Probe` CRD — rejected as less familiar and needing a prober-URL model; revisit later.
10. **Extra args** (`extraArgs: []`) rather than per-collector values: the collector flag set changes between releases.
11. **Release metadata:** `CHANGELOG.md` with `## [0.1.0]` and `[Unreleased]`; never hand-edit `Chart.yaml` version after the initial file (the release workflow syncs it).

## Risks / Trade-offs

- [Read-only root FS or uid 101 breaks startup] → verify with `helm template` plus a documented manual run on a cluster (human-in-the-loop task); values allow relaxing `securityContext`.
- [`/` probe path unverified] → verify against the image before finalising; fall back to tcpSocket.
- [Unit tests can't prove scrape behaviour or Proxmox auth] → manual verification recipe against a real PVE host is a human-in-the-loop task.
- [ServiceMonitor CRD absent] → disabled by default; documented.
- [Exporter `cluster`/`node` defaults undocumented] → always sent explicitly, defaults `"1"`/`"1"` per the README example.
- [Env-mode cannot use a custom CA path] → document `pve.yml` mode for that case.

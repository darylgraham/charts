# Spec Delta

## Purpose

Defines how the prometheus-pve-exporter chart deploys the exporter and supplies it with Proxmox VE credentials and configuration, so that an install with minimal values yields a working, secure exporter.

## ADDED Requirements

### Requirement: Exporter workload
The chart SHALL deploy the exporter as a Deployment exposing a Service on port 9221, using image `prompve/prometheus-pve-exporter` at a tag defaulting to the chart appVersion.

#### Scenario: Default install renders workload
- **WHEN** the chart is rendered with the required credential values set
- **THEN** a Deployment and a ClusterIP Service on port 9221 are produced
- **AND** the container image tag equals `appVersion` without a `v` prefix

#### Scenario: Image override
- **WHEN** `image.tag` is set
- **THEN** the container uses that tag instead of `appVersion`

### Requirement: Credentials from a chart-managed Secret
The chart SHALL create a Secret holding Proxmox credentials from values and inject them into the container as `PVE_*` environment variables, supporting password authentication and API-token authentication.

#### Scenario: Password authentication
- **WHEN** `pve.user` and `pve.password` are set
- **THEN** a Secret is rendered containing both values
- **AND** the container receives `PVE_USER` and `PVE_PASSWORD` from that Secret

#### Scenario: Token authentication
- **WHEN** `pve.user`, `pve.tokenName` and `pve.tokenValue` are set
- **THEN** the container receives `PVE_USER`, `PVE_TOKEN_NAME` and `PVE_TOKEN_VALUE` from the Secret and no `PVE_PASSWORD`

#### Scenario: Missing credentials rejected
- **WHEN** no user is configured and no existing Secret or config file is supplied
- **THEN** rendering fails with a message naming the missing value

### Requirement: Credentials from an existing Secret
The chart SHALL allow credentials to come from a user-managed Secret with configurable key names, in which case it SHALL NOT create a credentials Secret.

#### Scenario: Existing Secret used
- **WHEN** `pve.existingSecret` is set
- **THEN** no credentials Secret is rendered
- **AND** the container environment references the named Secret and configured keys

### Requirement: Credentials never in ConfigMaps or output
The chart SHALL NOT render credential values into a ConfigMap, container args, or NOTES output.

#### Scenario: No plaintext secrets outside Secret
- **WHEN** the chart is rendered with credentials set
- **THEN** the only rendered object containing the password or token value is the credentials Secret

### Requirement: TLS verification control
The chart SHALL expose whether the exporter verifies the Proxmox server certificate, defaulting to verification enabled, and SHALL allow mounting a CA bundle from a Secret for use by a mounted `pve.yml`.

#### Scenario: Verification default
- **WHEN** the chart is rendered with defaults
- **THEN** `PVE_VERIFY_SSL` is `true`

#### Scenario: Verification disabled
- **WHEN** `pve.verifySsl` is `false`
- **THEN** `PVE_VERIFY_SSL` is `false`

### Requirement: Mounted configuration file
The chart SHALL support supplying a full `pve.yml` (multiple modules) from a chart-created Secret or an existing Secret, mounted at `/etc/prometheus/pve.yml`, and SHALL NOT also set `PVE_*` credential variables in that mode.

#### Scenario: Inline config
- **WHEN** `config.pveYml` is set
- **THEN** a Secret holding that content is mounted at `/etc/prometheus/pve.yml`
- **AND** no `PVE_USER` variable is set

### Requirement: Exporter flags
The chart SHALL allow arbitrary exporter arguments (such as `--no-collector.config`) via values.

#### Scenario: Extra args
- **WHEN** `extraArgs` lists `--no-collector.config`
- **THEN** the container args include it

### Requirement: Hardened and standard pod settings
The chart SHALL default to a non-root, read-only-root-filesystem, capability-dropped container, and SHALL support the standard knobs: resources, nodeSelector, tolerations, affinity, imagePullSecrets, service account, pod annotations and labels, and name overrides.

#### Scenario: Security defaults
- **WHEN** the chart is rendered with defaults
- **THEN** the container runs as non-root with `readOnlyRootFilesystem: true` and all capabilities dropped

### Requirement: Health probes
The chart SHALL define liveness and readiness probes against the exporter's HTTP port.

#### Scenario: Probes present
- **WHEN** the chart is rendered with defaults
- **THEN** the container has both probes targeting the named `http` port

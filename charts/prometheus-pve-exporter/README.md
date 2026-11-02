# prometheus-pve-exporter

A Helm chart for deploying [prometheus-pve-exporter](https://github.com/prometheus-pve/prometheus-pve-exporter), a Prometheus exporter for Proxmox VE.

One exporter instance can scrape any number of Proxmox VE hosts: Prometheus passes the host to query as the `target` parameter of `/pve`.

> [!NOTE]
> Two behaviours are expected but not yet verified against a real cluster and image: the `/` HTTP probe path returning 2xx under the read-only root filesystem, and the exporter honouring `REQUESTS_CA_BUNDLE` (env-mode CA, see [TLS](#tls-and-custom-ca)). Both are tracked for verification before the first release.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2+
- A Proxmox VE user or API token with the `PVEAuditor` role (see [Proxmox VE setup](#proxmox-ve-setup))
- Optional: the Prometheus Operator CRDs, for the `ServiceMonitor`

## Installation

```bash
helm repo add darylgraham https://darylgraham.github.io/charts
helm repo update

helm install pve-exporter darylgraham/prometheus-pve-exporter \
  --set pve.user=monitoring@pve \
  --set pve.password=CHANGE_ME
```

The Service is named `<release>-prometheus-pve-exporter` (just `<release>` when the release name already contains the chart name) and listens on port `9221`. Ready-made values files are in [`examples/`](./examples).

## Proxmox VE setup

The exporter only reads data, so give it the built-in read-only `PVEAuditor` role on the root path `/`.

Token authentication (recommended):

```bash
pveum user add monitoring@pve
pveum aclmod / -user monitoring@pve -role PVEAuditor
pveum user token add monitoring@pve exporter --privsep 0
```

`--privsep 0` makes the token inherit the user's permissions. If you keep privilege separation enabled (the default), grant the role to the token itself instead:

```bash
pveum aclmod / -token 'monitoring@pve!exporter' -role PVEAuditor
```

Password authentication:

```bash
pveum user add monitoring@pve --password CHANGE_ME
pveum aclmod / -user monitoring@pve -role PVEAuditor
```

## Authentication modes

Exactly one mode applies. Misconfigurations (missing user, password together with a token, both `config.pveYml` and `config.existingSecret`, ...) fail at render time with a message.

| Mode | Selected by | Example |
|------|-------------|---------|
| Password | `pve.user` + `pve.password` | [`examples/password.yaml`](./examples/password.yaml) |
| API token | `pve.tokenName` (or `pve.tokenNameKey` / `pve.tokenValueKey`) | [`examples/token.yaml`](./examples/token.yaml) |
| Existing Secret | `pve.existingSecret` | [`examples/existing-secret.yaml`](./examples/existing-secret.yaml) |
| Mounted `pve.yml` | `config.pveYml` or `config.existingSecret` | [`examples/pve-yml-multi-module.yaml`](./examples/pve-yml-multi-module.yaml) |

Password and token modes export `PVE_USER` and either `PVE_PASSWORD` or `PVE_TOKEN_NAME` / `PVE_TOKEN_VALUE` from a Secret; `PVE_VERIFY_SSL` is set directly from `pve.verifySsl`.

```yaml
# password
pve:
  user: monitoring@pve
  password: CHANGE_ME
```

```yaml
# API token
pve:
  user: monitoring@pve
  tokenName: exporter
  tokenValue: CHANGE_ME
```

```yaml
# existing Secret (create it yourself, e.g. with External Secrets or SOPS)
pve:
  existingSecret: pve-credentials
  # token mode instead of password: tokenName: exporter, plus tokenNameKey/tokenValueKey
  # naming the keys in your Secret
```

With `pve.existingSecret` the chart creates no Secret and stores no credentials. The mode is still chosen from `pve.tokenName`, `pve.tokenNameKey` and `pve.tokenValueKey`, and the key names default to `user`, `password`, `tokenName` and `tokenValue`.

### Mounted `pve.yml` (config mode)

For several modules (for example separate clusters, or one with a custom CA) mount a `pve.yml`. It is mounted at `/etc/prometheus/pve.yml` from a Secret, because it holds credentials:

```yaml
config:
  pveYml: |
    default:
      user: monitoring@pve
      token_name: exporter
      token_value: CHANGE_ME
      verify_ssl: true
    lab:
      user: monitoring@pve
      password: CHANGE_ME
      verify_ssl: false
```

or reference your own Secret with `config.existingSecret` (and `config.existingSecretKey`). In config mode no `PVE_*` variables are set. The chart rejects `pve.user`, `pve.password`, `pve.tokenName`, `pve.tokenValue`, `pve.existingSecret`, `pve.tokenNameKey` / `pve.tokenValueKey` and `pve.verifySsl: false` in this mode; set `verify_ssl` in the `pve.yml` instead. Prometheus picks a module with the `module` query parameter.

## TLS and custom CA

`pve.verifySsl` (default `true`) controls certificate verification in env mode. For a Proxmox VE host with a private CA, put the CA certificate in a Secret and set `tls.caSecret`:

```bash
kubectl create secret generic pve-ca --from-file=ca.crt=./pve-ca.crt
```

```yaml
tls:
  caSecret: pve-ca
```

The Secret is mounted read-only at `tls.caMountPath` (default `/etc/prometheus/ca`). This snippet is a fragment: combine it with one of the credential modes above.

- **Env mode:** the chart also sets `REQUESTS_CA_BUNDLE=<caMountPath>/<caKey>`. This relies on the exporter's HTTP client honouring that variable; it is expected to, but this is not yet verified against the image.
- **Config mode:** no variable is set. Point `verify_ssl` in your `pve.yml` at the file, e.g. `verify_ssl: /etc/prometheus/ca/ca.crt`.

## Exporter flags

Extra arguments are appended to the container args (combine with one of the credential modes above):

```yaml
extraArgs:
  - --no-collector.config
```

## ServiceMonitor

Requires the Prometheus Operator CRDs. Disabled by default.

```yaml
serviceMonitor:
  enabled: true
  labels:
    release: prometheus   # whatever your Prometheus selects ServiceMonitors by
  params:
    module: default
    cluster: "1"
    node: "1"
  targets:
    - pve1.example.com
    - target: pve2.example.com
      module: lab
      cluster: "0"
```

This snippet is a fragment: combine it with one of the credential modes above. [`examples/servicemonitor.yaml`](./examples/servicemonitor.yaml) is the complete values file.

- Each target renders one endpoint scraping `/pve` with its own `target` parameter and an `instance` label set to the target.
- A target is a host string (uses the global `params`) or a map `{ target, module, cluster, node }` whose optional keys override `params` for that endpoint. `target` is required in map form, a `null` override falls back to `params`, and empty targets are rejected.
- Parameter values are sent as strings, so write `"0"` / `"1"` (quoted).
- With no targets, one endpoint is rendered without `target` or `instance` relabeling (an exporter running on the Proxmox VE host itself).
- Every target is scraped once per exporter pod, so keep `replicaCount: 1` unless you want duplicate series.
- The `module` must exist: `default` is built in for env mode; any other module needs a mounted `pve.yml`.
- `relabelings` are appended after the chart's own; `metricRelabelings` apply to every endpoint.

## Plain Prometheus (without the Operator)

Without the Prometheus Operator, add a scrape job instead. The Proxmox VE host is the scrape target; `__param_target` hands it to the exporter and `__address__` is rewritten to the exporter Service:

```yaml
scrape_configs:
  - job_name: pve
    metrics_path: /pve
    params:
      module: [default]
      cluster: ["1"]
      node: ["1"]
    static_configs:
      - targets:
          - pve1.example.com   # Proxmox VE hosts to query
          - pve2.example.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: pve-exporter-prometheus-pve-exporter.monitoring.svc:9221   # <release>-prometheus-pve-exporter.<namespace>.svc:<service.port>, default 9221
```

## Security

- **Secrets and rollouts:** the pod template carries a `checksum/secret` annotation for chart-managed Secrets, so changing credentials or `config.pveYml` rolls the pod. Existing Secrets (`pve.existingSecret`, `config.existingSecret`) get no checksum; restart the Deployment yourself after changing them.
- **Checksum exposure:** the annotation is a sha256 of the rendered Secret, so anyone who can `get pods` could test password guesses offline. This is the standard Helm pattern; prefer token authentication or an existing Secret.
- **Service account:** `serviceAccount.automount` is `false`; the exporter does not talk to the Kubernetes API.
- **Hardened defaults:** the pod runs as non-root uid/gid 101 with `RuntimeDefault` seccomp, no privilege escalation, all capabilities dropped and a read-only root filesystem, with an `emptyDir` mounted at `/tmp`. Relax these through `podSecurityContext` and `securityContext` if your environment requires it.

## Known limits

- The liveness and readiness probes use `GET /`. This is expected to return 2xx under the read-only root filesystem but is not yet verified on a real cluster; if it does not, switch both probes to `tcpSocket` on port `http`.
- Env-mode CA trust through `REQUESTS_CA_BUNDLE` is not yet verified (see above).
- The Service port is configurable but the container always listens on `9221`.

## Values

### General

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of exporter replicas | `1` |
| `image.repository` | Exporter image repository | `prompve/prometheus-pve-exporter` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.tag` | Image tag; defaults to the chart `appVersion` (tags have no `v` prefix) | `""` |
| `imagePullSecrets` | Secrets used to pull the image from a private registry | `[]` |
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the fully qualified release name | `""` |
| `extraArgs` | Additional exporter arguments, e.g. `["--no-collector.config"]` | `[]` |
| `resources` | Container resource requests and limits | `{}` |
| `nodeSelector` | Node selector for pod scheduling | `{}` |
| `tolerations` | Tolerations for pod scheduling | `[]` |
| `affinity` | Affinity rules for pod scheduling | `{}` |

### Service account, pod and security context

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a service account | `true` |
| `serviceAccount.automount` | Mount the service account token into the pod | `false` |
| `serviceAccount.annotations` | Annotations added to the service account | `{}` |
| `serviceAccount.name` | Service account name; defaults to the fullname when `create` is true, otherwise `default` | `""` |
| `podAnnotations` | Annotations added to the pod | `{}` |
| `podLabels` | Extra labels added to the pod | `{}` |
| `podSecurityContext` | Pod-level security context (uid/gid/fsGroup 101, `runAsNonRoot`, `RuntimeDefault` seccomp) | see `values.yaml` |
| `securityContext` | Container-level security context (no privilege escalation, read-only root filesystem, drop `ALL`) | see `values.yaml` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port (the container always listens on 9221) | `9221` |

### Proxmox VE credentials (env mode)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `pve.user` | Proxmox VE user, e.g. `monitoring@pve` (`PVE_USER`); required unless `pve.existingSecret` is set | `""` |
| `pve.password` | Password for password authentication; cannot be combined with token authentication | `""` |
| `pve.tokenName` | API token name (`PVE_TOKEN_NAME`); setting it selects token mode | `""` |
| `pve.tokenValue` | API token value (`PVE_TOKEN_VALUE`); required with `tokenName` | `""` |
| `pve.verifySsl` | Verify the Proxmox VE certificate (`PVE_VERIFY_SSL`); rejected when `false` in config mode | `true` |
| `pve.existingSecret` | Existing Secret holding the credentials; the chart creates no Secret | `""` |
| `pve.userKey` | Key of the user in the Secret | `user` |
| `pve.passwordKey` | Key of the password in the Secret (password mode) | `password` |
| `pve.tokenNameKey` | Key of the token name in the Secret; setting it selects token mode (falls back to `tokenName`); not allowed in config mode | `""` |
| `pve.tokenValueKey` | Key of the token value in the Secret (falls back to `tokenValue`); not allowed in config mode | `""` |

### Mounted `pve.yml` (config mode)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.pveYml` | Contents of a `pve.yml` mounted at `/etc/prometheus/pve.yml` from a chart-created Secret; enables config mode | `""` |
| `config.existingSecret` | Existing Secret holding a `pve.yml`; enables config mode; mutually exclusive with `config.pveYml` | `""` |
| `config.existingSecretKey` | Key of the `pve.yml` in the existing Secret | `pve.yml` |

### TLS

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tls.caSecret` | Secret holding a CA certificate, mounted read-only; in env mode also sets `REQUESTS_CA_BUNDLE` | `""` |
| `tls.caKey` | Key of the CA certificate in the Secret | `ca.crt` |
| `tls.caMountPath` | Directory the CA Secret is mounted at | `/etc/prometheus/ca` |

### ServiceMonitor

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceMonitor.enabled` | Render a Prometheus Operator ServiceMonitor | `false` |
| `serviceMonitor.namespace` | ServiceMonitor namespace; defaults to the release namespace | `""` |
| `serviceMonitor.labels` | Extra labels, e.g. `release: prometheus` | `{}` |
| `serviceMonitor.annotations` | Annotations added to the ServiceMonitor | `{}` |
| `serviceMonitor.interval` | Scrape interval | `30s` |
| `serviceMonitor.scrapeTimeout` | Scrape timeout; must not exceed the interval | `10s` |
| `serviceMonitor.params.module` | Module from `pve.yml` to use | `default` |
| `serviceMonitor.params.cluster` | Collect cluster metrics (`"1"` or `"0"`) | `"1"` |
| `serviceMonitor.params.node` | Collect node metrics (`"1"` or `"0"`) | `"1"` |
| `serviceMonitor.targets` | Proxmox VE hosts to scrape: strings or maps `{ target, module, cluster, node }`; empty means a single endpoint without `target` | `[]` |
| `serviceMonitor.relabelings` | Extra relabelings appended to every endpoint after the chart's own | `[]` |
| `serviceMonitor.metricRelabelings` | Metric relabelings applied to every endpoint | `[]` |

### Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe` | Liveness probe for the exporter container | `GET /` on port `http`, delay 5s, period 10s |
| `readinessProbe` | Readiness probe for the exporter container | `GET /` on port `http`, delay 5s, period 10s |

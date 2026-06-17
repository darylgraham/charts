# home-information

A Helm chart for deploying [Home Information](https://github.com/cassandra/home-information) on Kubernetes.

> [!IMPORTANT]
> This chart is still in alpha and has not been fully tested yet. See [To-Do](./TODO.md) for more details.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2+

## Installation

```bash
helm repo add darylgraham https://darylgraham.github.io/charts
helm repo update

helm install home-information darylgraham/home-information \
  --set config.auth.adminEmail=admin@example.com
```

## Configuration

### Quick Start

The minimal required value is `config.auth.adminEmail`. By default the chart runs with an ephemeral SQLite database and no persistent storage — suitable for evaluation. For production, enable persistence and configure a Redis cache.

### Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `ghcr.io/cassandra/home-information` |
| `image.tag` | Container image tag | `v1.2.3` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | List of image pull secret names | `[]` |
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the full release name | `""` |

#### Authentication

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.auth.enabled` | Enable authentication | `true` |
| `config.auth.adminEmail` | Administrator login email (required) | `"admin@no-email.com"` |
| `config.auth.secretName` | Name of the Secret to create for the admin password | `""` |
| `config.auth.existingSecret` | Name of an existing Secret containing the admin password | `""` |
| `config.auth.existingSecretKey` | Key within the existing Secret | `DJANGO_SUPERUSER_PASSWORD` |

When `config.auth.existingSecret` is not set, a Secret is generated automatically with a random admin password. Retrieve it with:

```bash
kubectl get secret <release-name>-secret -o jsonpath='{.data.DJANGO_SUPERUSER_PASSWORD}' | base64 -d
```

#### Application Secret Key

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.existingSecretName` | Name of an existing Secret containing the Django secret key | `""` |
| `config.existingSecretKey` | Key within the existing Secret | `""` |

When not set, a secret key is auto-generated.

#### ConfigMap

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.existingConfigMap` | Name of an existing ConfigMap to use instead of creating one | `""` |

#### Cache (Redis)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.cache.hostname` | Redis hostname | `""` |
| `config.cache.port` | Redis port | `6379` |
| `config.cache.prefix` | Redis key prefix | `""` |

#### Email

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.email.subjectPrefix` | Email subject prefix | `""` |
| `config.email.fromEmail` | Default from address | `""` |
| `config.email.serverEmail` | Server email address | `""` |
| `config.email.serverHost` | SMTP host | `""` |
| `config.email.serverPort` | SMTP port | `587` |
| `config.email.credentialsSecret` | Name of a Secret with `username` and `password` keys for SMTP auth | `""` |
| `config.email.useTls` | Use STARTTLS | `false` |
| `config.email.useSsl` | Use implicit TLS | `false` |

#### Persistence

By default both volumes use `emptyDir` and data is lost on pod restart. Enable PVCs for durable storage.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.database.enabled` | Create a PVC for the SQLite database | `false` |
| `persistence.database.existingClaim` | Use an existing PVC | `""` |
| `persistence.database.storageClass` | Storage class | `""` |
| `persistence.database.accessMode` | Access mode | `ReadWriteOnce` |
| `persistence.database.size` | Volume size | `1Gi` |
| `persistence.media.enabled` | Create a PVC for uploaded media | `false` |
| `persistence.media.existingClaim` | Use an existing PVC | `""` |
| `persistence.media.storageClass` | Storage class | `""` |
| `persistence.media.accessMode` | Access mode | `ReadWriteOnce` |
| `persistence.media.size` | Volume size | `1Gi` |

#### Networking

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes Service type | `ClusterIP` |
| `service.port` | Application port | `8000` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress host rules | see `values.yaml` |
| `ingress.tls` | Ingress TLS configuration | `[]` |
| `httpRoute.enabled` | Enable Gateway API HTTPRoute (requires Gateway API CRDs) | `false` |
| `httpRoute.parentRefs` | Gateway references | see `values.yaml` |
| `httpRoute.hostnames` | HTTPRoute hostnames | `[chart-example.local]` |

#### Other

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.extraCspUrls` | Extra URLs added to the Content Security Policy | `[]` |
| `serviceAccount.create` | Create a ServiceAccount | `true` |
| `serviceAccount.automount` | Automount ServiceAccount token | `true` |
| `serviceAccount.annotations` | ServiceAccount annotations | `{}` |
| `serviceAccount.name` | ServiceAccount name override | `""` |
| `podAnnotations` | Annotations to add to pods | `{}` |
| `podLabels` | Labels to add to pods | `{}` |
| `podSecurityContext` | Pod-level security context | `{}` |
| `securityContext` | Container-level security context | `{}` |
| `resources` | CPU/memory resource requests and limits | `{}` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `volumes` | Extra volumes to add to the Deployment | `[]` |
| `volumeMounts` | Extra volume mounts to add to the container | `[]` |

## Examples

Examples can be found in the `examples/` directory.

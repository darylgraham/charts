# Helm Charts

A collection of Helm charts for deploying applications on Kubernetes.

## Usage

Add this repository to Helm:

```bash
helm repo add darylgraham https://darylgraham.github.io/charts
helm repo update
```

## Charts

| Chart | Description | Version |
|-------|-------------|---------|
| [home-information](charts/home-information/README.md) | Helm chart for deploying Home Information on Kubernetes | 0.1.0 |

## Development

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/) v3+
- [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin

### Setup

Install the required Helm plugins:

```bash
make init
```

### Running Tests

```bash
make test
```

# Spec Delta

## Purpose

Defines how Prometheus is wired to scrape the deployed exporter, including the multi-target pattern where one exporter queries several Proxmox VE hosts.

## ADDED Requirements

### Requirement: Optional ServiceMonitor
The chart SHALL render a Prometheus Operator ServiceMonitor only when explicitly enabled, and SHALL scrape the exporter's `/pve` path.

#### Scenario: Disabled by default
- **WHEN** the chart is rendered with defaults
- **THEN** no ServiceMonitor is rendered

#### Scenario: Enabled
- **WHEN** `serviceMonitor.enabled` is `true`
- **THEN** a ServiceMonitor selecting the chart's Service labels is rendered with path `/pve`

### Requirement: Scrape parameters
The ServiceMonitor SHALL send `module`, `cluster` and `node` query parameters from values, and SHALL support one or more Proxmox targets, each scraped with its own `target` parameter and `instance` label.

#### Scenario: Multiple targets
- **WHEN** `serviceMonitor.targets` lists two hosts
- **THEN** two scrape endpoints are rendered, each with its own `target` parameter

#### Scenario: Parameters configurable
- **WHEN** `serviceMonitor.params.cluster` is `"0"` and `node` is `"1"`
- **THEN** the rendered endpoint sends `cluster=0` and `node=1`

### Requirement: ServiceMonitor customisation
The ServiceMonitor SHALL support custom labels, interval, scrape timeout, and namespace.

#### Scenario: Release label for operator selection
- **WHEN** `serviceMonitor.labels` sets `release: prometheus`
- **THEN** the rendered ServiceMonitor carries that label

### Requirement: Documented plain-Prometheus scrape
The chart documentation SHALL include a scrape configuration for Prometheus installations without the Operator.

#### Scenario: README example
- **WHEN** a user reads the chart README
- **THEN** it contains a `scrape_configs` example using `metrics_path: /pve` and `__param_target` relabeling

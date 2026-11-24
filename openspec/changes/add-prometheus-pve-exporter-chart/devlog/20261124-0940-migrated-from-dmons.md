# Migrated from dmons

Seeded from `DEVLOG.md` (left untouched as history) when the repo moved from the dmons workflow to emmz.

## Landed

- Section 1 (base `90239e9`): `07bcc49` deps, `cbcfa23` block 1.1–1.3, `6cc0ac5` supervisor remediation. Supervisor `Approve` (round 2).
- Section 2 (base `2012251`): `13cf0b7` 2.1–2.2, `1a7848d` 2.3, `7bc20c0` 2.4. Supervisor `Approve`. (`0553302` outline lint fix was out of scope.)
- Section 3 (base `f6d32f3`): `51e7490` 3.1. Supervisor `Approve`.
- Section 4 (base `51e7490`): `3da5088` chart fixes (4.3), `02ae244` README + root registration (4.1–4.3), `ce0b471` close section, amend 4.4. Merged to main as #2.
- tasks.md: 11/12 ticked. Only 4.4 (human verification) remains. No unresolved `STOPPED` post.

## Next

- **4.4:** Product Owner runs the recipe in `DEVLOG.md` (`## 4.`). On pass: a docs block removes the "not yet verified" wording from the chart README (extend CHANGELOG `[0.1.0]`, not `[Unreleased]`), tick 4.4, propose `/opsx:archive`.
- **If 4.4 fails:** probe `/` not 2xx -> remediation block switching probes to `tcpSocket` (values + tests); `REQUESTS_CA_BUNDLE` not honoured -> Product Owner decision on design 6 and the "CA bundle in env mode" scenario.
- **Moved to `fix-ci-pipelines`:** the release-workflow follow-up (repo definitions for Bitnami/dex so chart-releaser can package `outline` and reach `prometheus-pve-exporter`) and the CI nit (`ci.yml` runs neither `make` nor the example render and does not fetch deps). The old "don't merge before 4.4 passes" caveat is moot: #2 already merged.
- **Nits (non-blocking):** `home-information/examples/flux-minimal.yaml` is a Flux manifest, not a values file (renders green, proves nothing); `*.yml` examples are skipped by `make lint`; root README Version column is hand-maintained and stale for home-information; chart `icon` skipped (no stable URL in repo).

# Dependencies

Every tool and login the project needs. `make deps` checks each row; keep the two in step.

| Tool | Check | Version | Auth check | Install |
|---|---|---|---|---|
| make | `make --version` | any | n/a | `apt install make` |
| helm | `helm version --short` | 3.x (CI pins v3.22.1) | n/a | https://helm.sh/docs/intro/install/ |
| helm-unittest plugin | `helm plugin list` (contains `unittest`) | 1.2.1 (pinned in `make init`) | n/a | `make init` |
| helmfmt | `helmfmt --version` | 0.7.0 (CI pins the v0.7.0 release) | n/a | release tarball from github.com/digitalstudium/helmfmt |
| openspec | `openspec --version` | 2.x | n/a | `npm i -g @fission-ai/openspec` |
| gh | `gh --version` | any | `gh auth status` | `apt install gh`, then `gh auth login` |

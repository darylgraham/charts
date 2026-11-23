# Helm Charts

A collection of Helm charts for deploying applications on Kubernetes (`charts/home-information`, and
`charts/outline`, a fork of the archived lrstanley outline chart), tested with helm-unittest and released
via chart-releaser from GitHub Actions.

Spec-driven development is managed with **OpenSpec** (`openspec/`). All feature work flows through a
change in `openspec/changes/`.

## Project notes

### Binding decisions
- **Charts are independent.** Each lives in `charts/<name>/` and stands alone; a block touches one chart
  unless the change's `design.md` says otherwise.
- **The CHANGELOG owns the version.** The release workflow rewrites `version:` in `Chart.yaml` from the
  top `## [x.y.z]` heading of the chart's `CHANGELOG.md`. Never hand-edit `version:`; record changes under
  `## [Unreleased]`. (`charts/outline` has no CHANGELOG, so the workflow skips it.)
- **Tests are helm-unittest suites** in `templates/tests/*.yaml`; a template change ships with a suite
  asserting rendered output.
- **`charts/outline` is a fork** of the archived lrstanley/helm-charts outline chart. Keep divergence
  deliberate and noted; no drive-by reformatting.
- **No secrets in the repo.** Credentials in values, examples, tests and docs are placeholders only
  (`__snapshot__/` is gitignored).

### Hazards
- **Render across value combinations:** defaults, optional features/subcharts off, Ingress vs HTTPRoute;
  guard optional blocks, `required` for must-set values.
- **Upgrade safety:** generated credentials (`lookup`) must be stable across `helm upgrade`; watch immutable
  fields (selectors, PVC specs, Jobs), renamed resources, changed `fullname`.
- **values.yaml compatibility:** renamed/removed keys are breaking: CHANGELOG entry + deprecation path;
  new keys default so existing installs render unchanged.
- **Selector labels** from `_helpers.tpl` match across Deployment/Service/PDB/NetworkPolicy and never
  include version-varying values.
- **Subchart seam (`outline`: postgresql, redis, minio, dex):** parent overrides, `condition:` flags and
  generated credentials stay consistent with what the subcharts expect.
- **Helm limitation:** `helm lint` reports a render-time `fail` only as `[INFO]` (exit 0); `make lint` also
  `helm template`s every `examples/*.yaml` to catch it.

## OpenSpec workflow

<!-- emmz-setup: 0.1.6 -->

Changes are tracked with OpenSpec. Build them with `/opsx:apply`, following this loop on top of it.
Notes go in the change's `devlog/` folder via `/emmz:devlog`.

### Gates

Run through the `Makefile`; a gate passed only if you saw its `LABEL_EXIT:0`. Quote exit lines, never
paraphrase them.

- `make test` — helm-unittest suites (`templates/tests/*.yaml`) for every chart.
- `make lint` — `helm lint` on every chart, plus `helm template` of every `examples/*.yaml`.
- `make format` — helmfmt check (never a rewrite).
- `make validate` — `openspec validate --strict` on every active change.
- `make gates` — all of the above.

`make deps` is separate: it checks that every tool and login in `docs/dependencies.md` is present.
(`make chart-deps` fetches subchart dependencies and is run by `test` and `lint`.)

### Starting a change

1. Ask which change to build, even if there is only one (`make changes`).
2. Resume point: the newest devlog note's `## Next` and the first unticked task in `tasks.md`. In a
   fresh session, `/emmz:pickup` does this and steps 3–5.
3. `make deps` → `DEPS_EXIT:0`. If not, stop: offer to install what's missing, and hand any login to the
   user as `! <cmd>` — never try to authenticate yourself.
4. Clean working tree (unless resuming a recorded stop), `make validate` green, on branch
   `change/<change-name>`.
5. Read `proposal.md`, `design.md`, and the specs the change touches.

A task that needs a tool, SDK, service or login not in `docs/dependencies.md` is a stop: ask before
adding it. Once agreed, add its row there and its check to `make deps` in the same section commit, and
say why in a devlog note.

### Each section (`## N.` in `tasks.md`), in order

1. Note the base commit (`git rev-parse --short HEAD`) — in a start note for larger sections.
2. Implement the section's tasks, with tests. Write a devlog note for any non-obvious decision. After
   each task, run the **context check** (below).
3. **Self-review** `git diff <base>` plus untracked files, against the spec requirements rather than
   just the tasks: missing requirements, untested behaviour, swallowed errors, dead or stub code,
   contracts that drifted from earlier sections, violations of `design.md ## Decisions`.
   Fix what you find.
4. `make gates` — all green. A section may land red only as a deliberate, stated call (e.g. a test a
   later section turns green), recorded in the devlog note and the commit body.
5. Tick the section's tasks and write the section-done devlog note. Assume the context will be cleared
   before the next section, so the note must be enough to resume from alone. Its `## Next` names the
   next section and its first task (or the whole-change review, after the last section). It also records
   anything this session knows that the repo doesn't: the user's answers, gotchas you hit, deferred
   nits, decisions in flight. Then make **one commit** for the section:
   ```
   feat(<change-name>): <section summary> (§N)

   - N.1 <task summary>
   - N.2 <task summary>
   ```
6. Run the **context check**, then carry on with the next section.

**Context check.** Call the `context_usage` tool. At 40% or under, carry straight on. Over 40%, run
`/emmz:handoff` so a cold session can resume from the repo alone, then call the `clear_and_pickup` tool
and end the turn: it runs `/clear`, then `/emmz:pickup`, which picks the work up where the handoff left
it. Mid-section, leave the section's work uncommitted; the handoff note records it. If either tool is
missing, run `/emmz:handoff` and end the turn by asking whether to `/clear` or restart `claude`.

### Finishing a change

1. Self-review the whole change, `git diff <first-section-base>..HEAD`: duplicated abstractions,
   leftover scaffolding, cross-section drift, and whether the spec is genuinely satisfied.
2. Write the change-done devlog note and report to the user. Then **offer** to run the `code-review`
   skill on the change branch before archiving, and run it if they say yes.
3. Fixes from either review don't land as loose commits. Add them to `tasks.md` as one or more new
   sections (`## N+1. Review fixes: <theme>`), agree them with the user, and build them with the
   section loop above, context checks included. Then return to step 2.
4. Once the review is done or declined and no fix sections are open, **offer** `/opsx:archive`, and
   wait for a yes.

### Stop and ask

Stop when: a requirement is ambiguous or contradicts the spec or design; scope would change; a task
needs human verification (installing or upgrading a chart on a real cluster, confirming Ingress or
HTTPRoute routing end to end, upgrading from the previously released chart version, a live Proxmox host
or a published release); or gates won't go green after two honest attempts.

To stop: leave work uncommitted and tasks unticked; write a `stopped-…` devlog note stating exactly what
blocked and the question; send a push notification if the tool is available; end the turn with the
question — for human verification, a copy-pasteable recipe. Never decide a product question yourself
and flag it afterwards.

Before the user ends a session or clears the context at any other point, run `/emmz:handoff`. Resume
with `/emmz:pickup`.

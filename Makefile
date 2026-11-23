# Helm charts — gate targets.
#
# Every gate prints its own exit code as `LABEL_EXIT:<n>` and exits with it, so a
# report can quote the code rather than an agent's reading of the output. This is
# not cosmetic: a tool can exit non-zero while printing output that reads exactly
# like a clean run.
#
# `gates` runs every gate in its set WITHOUT stopping at the first failure, so one
# invocation reports the whole picture instead of hiding the rest behind gate one.
#
# The active OpenSpec changes are discovered, not hardcoded, so the command string
# stays stable as changes come and go.

SHELL := /bin/bash

CHANGES := $(notdir $(patsubst %/,%,$(filter-out %/archive/,$(wildcard openspec/changes/*/))))

.PHONY: init helm-unittest deps chart-deps test lint format validate changes gates

init: helm-unittest
	echo "Container initialised..."

helm-unittest:
	helm plugin install https://github.com/helm-unittest/helm-unittest.git

# --- helm ----------------------------------------------------------------------

# `chart-deps` fetches subchart dependencies (`deps` is the tool/login check, below).
# Charts with subchart dependencies (outline) only lint/template once those are fetched;
# without them, values such as redis.master.service.ports are missing and templates error.
# Idempotent; `helm dependency build` honours Chart.lock.
chart-deps:
	@for c in charts/*/; do \
	  grep -q '^dependencies:' $$c/Chart.yaml || continue; \
	  grep -E '^[[:space:]]+repository: https?://' $$c/Chart.yaml | awk '{print $$2}' | sort -u | \
	    while read -r url; do helm repo add "$$(echo $$url | sed -E 's#https?://##; s#[^A-Za-z0-9]+#-#g')" "$$url" --force-update >/dev/null; done; \
	  helm dependency build $$c >/dev/null || exit 1; \
	done


test:
	@$(MAKE) --no-print-directory chart-deps || { echo "TEST_EXIT:1"; exit 1; }; \
	helm unittest ./charts/** -f templates/tests/*.yaml; code=$$?; echo "TEST_EXIT:$$code"; exit $$code

# `lint` also renders each chart with every examples/*.yaml values file. `helm lint` reports a
# render-time `fail` only as [INFO] (and exits 0), so `helm template` is used to catch broken
# example values (it checks render and YAML syntax, not the Kubernetes schema; *.yml is skipped).
lint:
	@$(MAKE) --no-print-directory chart-deps || { echo "LINT_EXIT:1"; exit 1; }; \
	code=0; helm lint ./charts/** || code=1; \
	for f in charts/*/examples/*.yaml; do \
	  [ -e "$$f" ] || continue; c="$$(dirname "$$(dirname "$$f")")"; \
	  out="$$(helm template lint-example "$$c" -f "$$f" 2>&1 >/dev/null)" || { echo "example failed to render: $$f"; echo "$$out"; code=1; }; \
	done; \
	echo "LINT_EXIT:$$code"; exit $$code

# helmfmt checks one chart at a time, so loop. A check, never a rewrite.
format:
	@fail=0; for c in charts/*/; do helmfmt --check $$c || fail=1; done; \
	echo "FORMAT_EXIT:$$fail"; exit $$fail

# --- spec ----------------------------------------------------------------------

# Validates every active change (archive excluded). No active change is a failure,
# not a silent pass — an empty run would otherwise report VALIDATE_EXIT:0 while
# having validated nothing.
validate:
	@fail=0; \
	if [ -z "$(CHANGES)" ]; then \
		echo "no active change found under openspec/changes/"; fail=1; \
	else \
		for c in $(CHANGES); do openspec validate $$c --strict || fail=1; done; \
	fi; \
	echo "VALIDATE_EXIT:$$fail"; exit $$fail

changes:
	@echo "$(CHANGES)"

# --- gate sets -----------------------------------------------------------------

gates:
	@$(MAKE) --no-print-directory -k lint test format validate; code=$$?; \
	echo "GATES_EXIT:$$code"; exit $$code

# Every tool and login in docs/dependencies.md — keep the two in step. Not part of
# `gates`: it checks the machine, not the code, and auth checks may need the network.
deps:
	@fail=0; \
	make --version >/dev/null 2>&1 || { echo "MISSING make — apt install make"; fail=1; }; \
	helm version --short 2>/dev/null | grep -q '^v3\.' || { echo "MISSING/WRONG VERSION helm — need 3.x"; fail=1; }; \
	helm plugin list 2>/dev/null | grep -q '^unittest' || { echo "MISSING helm-unittest — make init"; fail=1; }; \
	helmfmt --version >/dev/null 2>&1 || { echo "MISSING helmfmt"; fail=1; }; \
	openspec --version >/dev/null 2>&1 || { echo "MISSING openspec — npm i -g @fission-ai/openspec"; fail=1; }; \
	gh --version >/dev/null 2>&1 || { echo "MISSING gh — apt install gh"; fail=1; }; \
	gh auth status >/dev/null 2>&1 || { echo "NOT AUTHENTICATED gh — gh auth login"; fail=1; }; \
	echo "DEPS_EXIT:$$fail"; exit $$fail

# dmons-scaffold: 0.5.1
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

.PHONY: init helm-unittest deps test lint format validate changes gates

init: helm-unittest
	echo "Container initialised..."

helm-unittest: deps
	helm plugin install https://github.com/helm-unittest/helm-unittest.git

# --- helm ----------------------------------------------------------------------

# Charts with subchart dependencies (outline) only lint/template once those are fetched;
# without them, values such as redis.master.service.ports are missing and templates error.
# Idempotent; `helm dependency build` honours Chart.lock.
deps:
	@for c in charts/*/; do \
	  grep -q '^dependencies:' $$c/Chart.yaml || continue; \
	  grep -E '^[[:space:]]+repository: https?://' $$c/Chart.yaml | awk '{print $$2}' | sort -u | \
	    while read -r url; do helm repo add "$$(echo $$url | sed -E 's#https?://##; s#[^A-Za-z0-9]+#-#g')" "$$url" --force-update >/dev/null; done; \
	  helm dependency build $$c >/dev/null || exit 1; \
	done


test:
	@helm unittest ./charts/** -f templates/tests/*.yaml; code=$$?; echo "TEST_EXIT:$$code"; exit $$code

lint: deps
	@helm lint ./charts/**; code=$$?; echo "LINT_EXIT:$$code"; exit $$code

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

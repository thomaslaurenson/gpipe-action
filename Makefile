SHELL := /bin/bash
.SILENT:

GPIPE_VERSION ?=

.PHONY: help bump-gpipe ci clean

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

bump-gpipe: ## Update pinned gpipe version in action.yml. Usage: make bump-gpipe GPIPE_VERSION=v1.2.0
	@if [ -z "$(GPIPE_VERSION)" ]; then \
		printf 'Error: set GPIPE_VERSION=vX.Y.Z\n' >&2; \
		exit 1; \
	fi
	sed -i "s|default: v[0-9]*\.[0-9]*\.[0-9]*$$|default: $(GPIPE_VERSION)|" action.yml
	printf 'Bumped gpipe_version default to %s in action.yml\n' "$(GPIPE_VERSION)"

ci: ## Run all CI checks locally
	@echo "No local CI checks configured (action is YAML-only)"

clean: ## Remove build artifacts
	rm -rf bin/ dist/

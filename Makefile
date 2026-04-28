SHELL := /bin/bash
.SILENT:

GPIPE_VERSION ?=
GPIPE_PATH    ?=

.PHONY: help \
	sync validate \
	ci \
	clean

help: ## Show this help message
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

# TASKS
sync: ## Sync gpipe source. Set GPIPE_VERSION=vX.Y.Z (GitHub) or GPIPE_PATH=../gpipe (local)
	if [ -n "$(GPIPE_PATH)" ]; then \
		printf 'Syncing gpipe from local path: %s\n' "$(GPIPE_PATH)"; \
		rsync -a --delete --exclude='.git' "$(GPIPE_PATH)/" vendor/gpipe/; \
		version=$$(cd "$(GPIPE_PATH)" && git describe --tags --always --dirty 2>/dev/null || echo dev); \
		echo "$$version" > vendor/gpipe/GPIPE_VERSION; \
		printf 'Synced gpipe %s\n' "$$version"; \
	elif [ -n "$(GPIPE_VERSION)" ]; then \
		printf 'Cloning gpipe %s from GitHub...\n' "$(GPIPE_VERSION)"; \
		git clone --depth=1 --branch "$(GPIPE_VERSION)" https://github.com/thomaslaurenson/gpipe /tmp/gpipe-sync; \
		rsync -a --delete --exclude='.git' /tmp/gpipe-sync/ vendor/gpipe/; \
		echo "$(GPIPE_VERSION)" > vendor/gpipe/GPIPE_VERSION; \
		rm -rf /tmp/gpipe-sync; \
		printf 'Synced gpipe %s\n' "$(GPIPE_VERSION)"; \
	else \
		printf 'Error: set GPIPE_VERSION=vX.Y.Z or GPIPE_PATH=../gpipe\n' >&2; \
		exit 1; \
	fi

validate: ## Verify vendored gpipe source builds correctly
	printf 'Building vendored gpipe (version: %s)...\n' "$$(cat vendor/gpipe/GPIPE_VERSION)"
	go build -C vendor/gpipe -o /dev/null .
	printf 'OK\n'

ci: validate ## Run all CI checks locally

clean: ## Remove build artifacts
	rm -rf bin/ dist/

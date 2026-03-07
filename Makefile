.PHONY: help install bootstrap lint test test-docker test-integration test-all \
       docs docs-build docs-preview clean

SHELL := /bin/bash

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Install ──────────────────────────────────────────────────────────────────

install: ## Run all scripts and workstation provisioning
	./install.sh

bootstrap: ## Bootstrap dotfiles from remote repo
	./bootstrap-dotfiles.sh

# ── Lint ─────────────────────────────────────────────────────────────────────

lint: ## Run ShellCheck on all scripts
	shellcheck scripts/*.sh

# ── Test ─────────────────────────────────────────────────────────────────────

test: ## Run unit tests locally (requires bats-core)
	bats tests/*.bats

test-docker: ## Run unit tests in Arch Linux Docker container
	docker build -f tests/Dockerfile.unit -t cachyos-unit-tests .
	docker run --rm cachyos-unit-tests

test-integration: ## Run integration tests in Arch Linux Docker container
	docker build -f tests/Dockerfile.integration -t cachyos-integration-tests .
	docker run --rm cachyos-integration-tests

test-all: lint test-docker test-integration ## Run lint, unit tests, and integration tests

# ── Docs ─────────────────────────────────────────────────────────────────────

docs: ## Start VitePress dev server
	npm run docs:dev

docs-build: ## Build VitePress site for production
	npm run docs:build

docs-preview: docs-build ## Build and preview VitePress site
	npm run docs:preview

# ── Clean ────────────────────────────────────────────────────────────────────

clean: ## Remove build artifacts
	rm -rf docs/.vitepress/dist docs/.vitepress/cache node_modules
